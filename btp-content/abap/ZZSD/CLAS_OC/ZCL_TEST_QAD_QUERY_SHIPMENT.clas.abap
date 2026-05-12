CLASS zcl_test_qad_query_shipment DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_TEST_QAD_QUERY_SHIPMENT IMPLEMENTATION.


METHOD if_oo_adt_classrun~main.
  " Using separate DATA statements for strict ABAP Cloud syntax
  DATA lo_qad_service         TYPE REF TO zcl_qad_queryshipment_svc.
  DATA ls_ship_key            TYPE zcl_qad_queryshipment_svc=>ty_qad_shipment_key.
  DATA lt_tracking            TYPE zcl_qad_queryshipment_svc=>tt_qad_tracking_info.
  DATA lt_errors              TYPE zcl_qad_queryshipment_svc=>tt_error_messages.
  DATA lv_final_data_received TYPE abap_bool.
  DATA lv_submission_accepted TYPE abap_bool.


  "====================================================================
  " SETUP: Generate a unique key for this specific test run
  "====================================================================
  DATA(lv_unique_ref) = |TEST_{ cl_abap_context_info=>get_system_time( ) }|.
  ls_ship_key-trax_client        = 'UK1'. " Your example QAD Client
  ls_ship_key-shipment_reference = '0001156'.

  out->write( |Generated unique Shipment Reference for this run: { lv_unique_ref }| ).
  out->write( '-------------------------------------------' ).


" <<< NEW: Get count *before* the call >>>
    SELECT COUNT(*) FROM zpar_trc_h INTO @DATA(lv_count_before).
    out->write( |Count in ZPAR_TRC_H before call: { lv_count_before }| ).

  "====================================================================
  " STEP 1: SUBMIT the initial message
  "====================================================================
  CREATE OBJECT lo_qad_service.
  out->write( 'Step 1: Calling submission method (query_shipment_info)...' ).

  TRY.
      lo_qad_service->query_shipment_info(
        EXPORTING
          iv_use_mock_data = abap_false
        IMPORTING
          et_errors        = lt_errors
        CHANGING
          cs_shipment_key  = ls_ship_key
      ).

      " <<< FIX: The WHERE clause now refers to components directly ('message') >>>
      LOOP AT lt_errors INTO DATA(ls_error) WHERE type = 'W' AND message CP '*accepted*'.
              out->write( ls_error ).
        " If a line is found that matches both conditions, we set the flag and exit the loop.
        lv_submission_accepted = abap_true.
        EXIT.
      ENDLOOP.

      IF lv_submission_accepted = abap_true.
        out->write( '>>> Submission accepted by Highway.' ).
      ELSE.
        out->write( 'Submission saved if new or updated:' ).
" <<< NEW: Get count *before* the call >>>
    SELECT COUNT(*) FROM zpar_trc_h INTO @DATA(lv_count_after).
    out->write( |Count in ZPAR_TRC_H after call: { lv_count_after }| ).
      ENDIF.

    CATCH zcx_qad_simple_error INTO DATA(lx_submit_error).
      out->write( |Critical Submission Error: { lx_submit_error->get_text( ) }| ).
      RETURN. " No point polling
  ENDTRY.




  "====================================================================
  " STEP 3: POLL for the final result
  "====================================================================
  out->write( 'Step 3: Starting to poll for query result...' ).
  DO  1 TIMES.
    CLEAR: lt_tracking, lt_errors.
   ls_ship_key-shipment_reference = |000| & |{ ls_ship_key-shipment_reference + 1 } |.
    ls_ship_key-log_uuid = |{ cl_abap_context_info=>get_system_time( ) }|.
    TRY.
        lo_qad_service->query_shipment_info(
        EXPORTING
          iv_use_mock_data = abap_false
        IMPORTING
          et_errors        = lt_errors
          CHANGING
          cs_shipment_key  = ls_ship_key

        ).

        " Check if we received the final data (tracking info OR a business error that is NOT a 'W'arning)
        DATA lv_is_warning_only TYPE abap_bool VALUE abap_true.
        LOOP AT lt_errors INTO ls_error.
          IF ls_error-type <> 'W'.
            lv_is_warning_only = abap_false.
            EXIT.
          ENDIF.
        ENDLOOP.

        IF lt_tracking IS NOT INITIAL OR ( lt_errors IS NOT INITIAL AND lv_is_warning_only = abap_false ).
          out->write( '>>> Final business response received!' ).
          lv_final_data_received = abap_true.
          EXIT. " Exit the polling loop
        ENDIF.

      CATCH zcx_qad_simple_error INTO DATA(lx_qad_error).
        out->write( |Critical Polling Error: { lx_qad_error->get_text( ) }| ).
        EXIT. " Exit loop on critical error
    ENDTRY.

    " If we are still here, it means we got the <Highway> receipt again
    out->write( |Attempt { sy-index }: Still processing. Response:| ).
    " <<< NEW: Get count *before* the call >>>
    SELECT COUNT(*) FROM zpar_trc_h INTO @lv_count_after.
    out->write( |Count in ZPAR_TRC_H after call: { lv_count_after }| ).


  ENDDO.

  out->write( '-------------------------------------------' ).
  IF lv_final_data_received = abap_true.
    out->write( 'Final Tracking Info:' ).
    out->write( lt_tracking ).
    out->write( 'Final Errors/Messages:' ).
    out->write( lt_errors ).
  ELSE.
    out->write( 'Polling finished, but final business response was not received. Please check QAD UI for your reference.' ).
  ENDIF.

ENDMETHOD.
ENDCLASS.