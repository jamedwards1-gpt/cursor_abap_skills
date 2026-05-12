CLASS zcl_btp_to_ecc_sync DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    METHODS execute_sync
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS fit_to_size
      IMPORTING
        val          TYPE string
        len          TYPE i
      RETURNING
        VALUE(result) TYPE string.
ENDCLASS.



CLASS ZCL_BTP_TO_ECC_SYNC IMPLEMENTATION.


  METHOD execute_sync.
    DATA: lt_sync_log TYPE STANDARD TABLE OF zpar_sync_log.
    DATA: lt_existing_logs TYPE STANDARD TABLE OF zpar_sync_log.

    " 1. READ SOURCE DATA
    " LIMIT TO 2 ROWS for testing purposes
    SELECT * FROM ZC_BTP_ParcelSync
      INTO TABLE @DATA(lt_source_data)
      UP TO 10 ROWS.

    IF lt_source_data IS INITIAL.
      out->write( 'No source data found in ZC_BTP_ParcelSync.' ).
      RETURN.
    ENDIF.

    " 2. CHECK LOG (Delta Handling)
    SELECT * FROM zpar_sync_log
      FOR ALL ENTRIES IN @lt_source_data
      WHERE erp_delivery_number = @lt_source_data-Vbeln
        AND qad_shipment_ref    = @lt_source_data-QadRef
        AND pack_number         = @lt_source_data-PackNumber
      INTO TABLE @lt_existing_logs.

    SORT lt_existing_logs BY erp_delivery_number qad_shipment_ref pack_number.

    " 3. SETUP PROXY FACTORY
    " We only create the Client Proxy here. The Request itself is created inside the loop.
    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_cloud_destination(
                                 i_name = 'FES'
                               ).

        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        DATA(lo_client_proxy) = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
                                  is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                                                      proxy_model_id      = 'ZSC_ECC_PARCEL'
                                                                      proxy_model_version = '0001' )
                                  io_http_client           = lo_http_client
                                  iv_relative_service_root = '/sap/opu/odata/sap/Z_PARCEL_TRAC_SRV/' ).

      CATCH cx_root INTO DATA(lx_setup).
        out->write( |Setup Error: { lx_setup->get_text( ) }| ).
        RETURN.
    ENDTRY.


    " 4. LOOP AND PUSH
    LOOP AT lt_source_data INTO DATA(ls_source).

      " Delta Check: Skip if already in the log
      READ TABLE lt_existing_logs TRANSPORTING NO FIELDS
        WITH KEY erp_delivery_number = ls_source-Vbeln
                 qad_shipment_ref    = ls_source-QadRef
                 pack_number         = ls_source-PackNumber
        BINARY SEARCH.

      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      " --- MAPPING ---
      DATA(lv_safe_track) = fit_to_size( val = CONV #( ls_source-TrackNum ) len = 35 ).
      DATA(lv_seq_num) = '0001'.

      DATA(ls_payload) = VALUE zsc_ecc_parcel=>tys_parcel_trac(
        vbeln      = ls_source-Vbeln
        posnr      = '000000'
        seq_num    = lv_seq_num
        track_num  = lv_safe_track
        carton_wt  = ls_source-Weight
        boxes      = '1'
        carton_qty = 1
        url        = ''
      ).

      TRY.
          " --- CREATE REQUEST (POST) ---
          " We create a NEW request object for every single iteration
          DATA(lo_request) = lo_client_proxy->create_resource_for_entity_set(
             zsc_ecc_parcel=>gcs_entity_set-parcel_trac_set
          )->create_request_for_create( ).

          lo_request->set_business_data( ls_payload ).
          DATA(lo_response) = lo_request->execute( ).

          " --- SUCCESS HANDLING ---
          GET TIME STAMP FIELD DATA(lv_current_ts).

          APPEND VALUE #(
            erp_delivery_number = ls_source-Vbeln
            qad_shipment_ref    = ls_source-QadRef
            pack_number         = ls_source-PackNumber
            synced_on           = lv_current_ts
            synced_by           = cl_abap_context_info=>get_user_technical_name( )
          ) TO lt_sync_log.

          out->write( |Synced Vbeln: { ls_source-Vbeln }| ).

      CATCH /iwbep/cx_cp_remote INTO DATA(lx_remote).
          " Gateway Error (401, 403, 500, etc.)
          out->write( |Error syncing { ls_source-Vbeln }: { lx_remote->get_text( ) }| ).

      CATCH cx_root INTO DATA(lx_general).
          " General Error
          out->write( |General Error: { lx_general->get_text( ) }| ).
      ENDTRY.

    ENDLOOP.

    " 5. UPDATE LOG
    IF lt_sync_log IS NOT INITIAL.
      INSERT zpar_sync_log FROM TABLE @lt_sync_log.
    ENDIF.

  ENDMETHOD.


  METHOD fit_to_size.
    DATA(lv_len) = strlen( val ).
    IF lv_len <= len.
      result = val.
    ELSE.
      result = val(len).
    ENDIF.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    me->execute_sync( out = out ).
  ENDMETHOD.
ENDCLASS.