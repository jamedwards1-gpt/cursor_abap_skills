CLASS zcl_seed_existing_shipment DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_SEED_EXISTING_SHIPMENT IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    " This program's only job is to add a known, existing shipment
    " to our polling queue, so we can test the query process in isolation.

    "====================================================================
    " 1. Define the key for the known shipment from your ERP system
    "====================================================================
    DATA ls_log_to_create TYPE zqad_poll_log.

    ls_log_to_create-client             = sy-mandt.

    ls_log_to_create-shipment_uuid      = cl_system_uuid=>create_uuid_x16_static( ).
    ls_log_to_create-shipment_reference = '0000998'. " <<< The known SHIPREF
    ls_log_to_create-status             = 'SUBMITTED'.
    ls_log_to_create-poll_count         = 0.


    "====================================================================
    " 2. Get a valid timestamp using the known, working method
    "====================================================================
    CALL METHOD cl_abap_utclong=>from_system_timestamp
      EXPORTING
        system_date  = cl_abap_context_info=>get_system_date( )
        system_time  = cl_abap_context_info=>get_system_time( )
      IMPORTING
      utc_tstmp = DATA(lv_current_utclong).

    ls_log_to_create-created_at            = lv_current_utclong.
    ls_log_to_create-last_changed_at       = lv_current_utclong.
    ls_log_to_create-local_last_changed_at = lv_current_utclong.


    "====================================================================
    " 3. Insert the new record into the database
    "====================================================================
    TRY.
        INSERT zqad_poll_log FROM @ls_log_to_create.
        IF sy-subrc = 0.
          out->write( |SUCCESS: Log entry created for existing shipment '{ ls_log_to_create-shipment_reference }'.| ).
          out->write( 'You can now run the ZCL_BATCH_POLL_QAD_STATUS class.' ).
        ELSE.
          out->write( 'ERROR: INSERT into zqad_poll_log failed.' ).
        ENDIF.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql_error).
        out->write( |Critical database error: { lx_sql_error->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.
ENDCLASS.