    CLASS zcl_batch_qad_query_runner DEFINITION
      PUBLIC
      FINAL
      CREATE PUBLIC.

      PUBLIC SECTION.
        INTERFACES if_oo_adt_classrun.
      PROTECTED SECTION.
      PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_BATCH_QAD_QUERY_RUNNER IMPLEMENTATION.


      METHOD if_oo_adt_classrun~main.
        " This program reads the log table and calls CHECK_SHIPMENT_STATUS
        " to get the results of pending jobs.
    "====================================================================
        " CONFIGURATION
        "====================================================================
        DATA(lv_batch_size) = 5.
        DATA(lv_trax_client) = 'AU1'.
        DATA lv_current_ship_num TYPE i.
        DATA lv_message     TYPE string.

        "====================================================================
        " INITIALIZATION
        "====================================================================
        DATA lo_qad_service TYPE REF TO zcl_qad_queryshipment_svc.
        DATA ls_ship_key    TYPE zcl_qad_queryshipment_svc=>ty_qad_shipment_key.
        DATA lt_tracking    TYPE zcl_qad_queryshipment_svc=>tt_qad_tracking_info.
        DATA lt_errors      TYPE zcl_qad_queryshipment_svc=>tt_error_messages.


        lv_message = |Batch polling process started at { cl_abap_context_info=>get_system_time( ) }|.
        out->write( lv_message ).
        out->write( '-------------------------------------------' ).

    "====================================================================
        " 1. Find the next shipment number to start from
        "====================================================================
        out->write( 'Checking ZPAR_TRC_H for the last known shipment...' ).

        TRY.
            " Find the highest shipment reference currently in the table
            SELECT MAX( qad_shipment_ref )
              FROM zpar_trc_h
              INTO @DATA(lv_max_ref).

            IF sy-subrc = 0 AND lv_max_ref IS NOT INITIAL.
              " Convert the CHAR value to an INT and add 1
              lv_current_ship_num = CONV i( lv_max_ref ).
              lv_message = |Last ref found: { lv_max_ref }. Starting next query from { lv_current_ship_num }.|.
              out->write( lv_message ).
            ELSE.
              " Table is empty or no max ref found, use the default start
              lv_current_ship_num = 1179.
              out->write( 'No existing shipments found. Starting from default: 1176.' ).
            ENDIF.

          CATCH cx_sy_conversion_error.
            " Handle cases where the ref is not a clean number
            out->write( |Error converting max ref '{ lv_max_ref }'. Defaulting to 1176.| ).
            lv_current_ship_num = 1179.
        ENDTRY.



        lv_message = |Found { lv_max_ref } shipment(s) to check.|.
        out->write( lv_message ).
        out->write( '-------------------------------------------' ).

        "====================================================================
        " 2. Instantiate the service and loop through the queue
        "====================================================================
        CREATE OBJECT lo_qad_service.
        DATA(lv_gap_found) = abap_false.

        DO lv_batch_size TIMES.
          CLEAR: lt_tracking, lt_errors.
          DATA(lv_final_data_received) = abap_false.

   ls_ship_key-shipment_reference = |000| & |{ lv_current_ship_num + 1 } |.
    ls_ship_key-log_uuid = |{ cl_abap_context_info=>get_system_time( ) }|.

        ls_ship_key-trax_client        = lv_trax_client.

          lv_message = |Querying for { ls_ship_key-shipment_reference }...|.
          out->write( lv_message ).

          ls_ship_key-shipment_reference = '0001176'.
          ls_ship_key-trax_client = 'AU1'.

           TRY.
              " Call the correct QUERY method
              lo_qad_service->query_shipment_info(
            EXPORTING
              iv_use_mock_data = abap_false
            IMPORTING
              et_errors        = lt_errors
              CHANGING
              cs_shipment_key  = ls_ship_key
              ).




              " Generate timestamp for the update
              DATA lv_current_utclong TYPE utclong.

                ls_ship_key-log_uuid = |{ cl_abap_context_info=>get_system_time( ) }|.


            CATCH zcx_qad_simple_error INTO DATA(lx_qad_error).
              lv_message = |!!! Critical polling error for { lx_qad_error->get_text( ) }|.
              out->write( lv_message ).
          ENDTRY.
          out->write( '-------------------------------------------' ).

          " 4. Act on the analysis
          IF lv_final_data_received = abap_true.
            " SUCCESS for this number
            lv_message = |>>> Success: Final response received for { ls_ship_key-shipment_reference }|.
            out->write( lv_message ).
            out->write( 'Final Tracking Info:' ).
            out->write( lt_tracking ).
            out->write( 'Final Errors/Messages:' ).
            out->write( lt_errors ).

          ELSE.
            " FAILURE / GAP FOUND (Got a <Highway> receipt)
            lv_message = |>>> Gap found at { ls_ship_key-shipment_reference }. Stopping process.|.
            out->write( lv_message ).
            out->write( lt_errors ).
            lv_gap_found = abap_true.
            EXIT. " Exit DO loop
          ENDIF.

          out->write( '-------------------------------------------' ).
          WAIT UP TO 1 SECONDS. " Small pause between calls
        ENDDO. " End of DO loop





        out->write( 'Polling process finished.' ).

      ENDMETHOD.
ENDCLASS.