CLASS zcl_test_existing_shipment DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_TEST_EXISTING_SHIPMENT IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    out->write( 'Attempting to query for a known, existing shipment...' ).
    out->write( '-------------------------------------------' ).

    "====================================================================
    " SETUP: Define the key for the shipment seen in the ERP system
    "====================================================================
    DATA ls_ship_key TYPE zcl_qad_queryshipment_svc=>ty_qad_shipment_key.

    " These values are taken directly from your ERP screenshot
    ls_ship_key-trax_client        = 'TMSCLI'.
    ls_ship_key-shipment_reference = '00651444'.

    out->write( |Querying for TRAXClient '{ ls_ship_key-trax_client }' and ShipmentReference '{ ls_ship_key-shipment_reference }' | ).


    "====================================================================
    " EXECUTE: Call the status check method directly
    "====================================================================
    DATA(lo_qad_service) = NEW zcl_qad_queryshipment_svc( ).

    TRY.
        lo_qad_service->check_shipment_status(
          EXPORTING
            is_shipment_key  = ls_ship_key
          IMPORTING
            et_tracking_info = DATA(lt_tracking)
            et_errors        = DATA(lt_errors)
        ).

        "====================================================================
        " ANALYZE: Display the results
        "====================================================================
        out->write( '-------------------------------------------' ).
        out->write( 'Query execution finished. Analyzing response...' ).

        IF lt_tracking IS NOT INITIAL.
          out->write( '>>> SUCCESS: Tracking data was found!' ).
          out->write( lt_tracking ).
        ENDIF.

        IF lt_errors IS NOT INITIAL.
          out->write( '>>> Messages/Errors returned from API:' ).
          out->write( lt_errors ).
        ELSEIF lt_tracking IS INITIAL.
          out->write( 'Query executed successfully but returned no tracking data and no error messages.' ).
        ENDIF.


      CATCH zcx_qad_simple_error INTO DATA(lx_qad_error).
        out->write( |!!! Critical Error during API call: { lx_qad_error->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx_root).
        out->write( |!!! Critical System Error: { lx_root->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.
ENDCLASS.