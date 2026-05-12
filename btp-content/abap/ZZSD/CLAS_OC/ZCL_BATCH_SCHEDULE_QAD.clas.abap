CLASS zcl_batch_schedule_qad DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_rt_run.
    INTERFACES if_apj_dt_defaults.

    DATA p_batch TYPE i.
    DATA p_client TYPE c LENGTH 3.


  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_BATCH_SCHEDULE_QAD IMPLEMENTATION.


  METHOD if_apj_dt_defaults~fill_attribute_defaults.
    p_batch = 5.
    p_client = 'UK1'.
  ENDMETHOD.


  METHOD if_apj_rt_run~execute.
   TRY.


    DATA lo_log    TYPE REF TO if_bali_log.
    DATA lo_header TYPE REF TO if_bali_header_setter.
    DATA lo_object  type ref to if_bali_header_setter=>ty_object.
    DATA lo_subobject   type ref to if_bali_header_setter=>ty_subobject.



        lo_log = cl_bali_log=>create( ).
        lo_header = cl_bali_header_setter=>create(
                        object    = 'ZCL_BATCH_SCHEDULE'
                        subobject = 'POLLING'
                    ).
        lo_log->set_header( lo_header ).

        lo_log->add_item( cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_status
            text     = |Batch polling process started at { cl_abap_context_info=>get_system_time( ) }|
        ) ).

        DATA(lv_batch_size) = p_batch.
        DATA(lv_trax_client) = p_client.

                lo_log->add_item( cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_status
            text     = |p_batch and p_client set { p_client } p_batch { p_batch }|
        ) ).

                lo_log->add_item( cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_status
            text     = 'Checking ZPAR_TRC_H for the last known shipment...'
        ) ).

        IF lv_batch_size IS INITIAL.
          lv_batch_size = 5.
          lo_log->add_item( cl_bali_free_text_setter=>create(
              severity = if_bali_constants=>c_severity_warning
              text     = 'No batch size parameter found, defaulting to 5.'
          ) ).
        ENDIF.

        IF lv_trax_client IS INITIAL.
          lv_trax_client = 'UK1'.
          lo_log->add_item( cl_bali_free_text_setter=>create(
              severity = if_bali_constants=>c_severity_warning
              text     = 'No trax client parameter found, defaulting to UK1.'
            ) ).
        ENDIF.

        DATA lv_current_ship_num TYPE i.
        DATA lv_message     TYPE c LENGTH 200.

        DATA lo_qad_service TYPE REF TO zcl_qad_queryshipment_svc.
        DATA ls_ship_key    TYPE zcl_qad_queryshipment_svc=>ty_qad_shipment_key.
        DATA lt_tracking    TYPE zcl_qad_queryshipment_svc=>tt_qad_tracking_info.
        DATA lt_errors      TYPE zcl_qad_queryshipment_svc=>tt_error_messages.

        lo_log->add_item( cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_status
            text     = 'Checking ZPAR_TRC_H for the last known shipment...'
        ) ).

        TRY.
            SELECT MAX( qad_shipment_ref )
              FROM zpar_trc_h
              WHERE trax_client = @p_client
              INTO @DATA(lv_max_ref).

            IF sy-subrc = 0 AND lv_max_ref IS NOT INITIAL.
              lv_current_ship_num = CONV i( lv_max_ref ).
              lv_message = |Last ref found: { lv_max_ref }. Starting query from { lv_current_ship_num }.|.
              lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'S' text = lv_message ) ).
            ELSE.
              lv_current_ship_num = 1176.
              lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'S' text = 'No existing shipments found. Starting from default: 1176.' ) ).
            ENDIF.

          CATCH cx_sy_conversion_error.
            lv_message = |Error converting max ref '{ lv_max_ref }'. Defaulting to 1176.|.
            lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'W' text = lv_message ) ).
            lv_current_ship_num = 1176.
        ENDTRY.


        CREATE OBJECT lo_qad_service.
        DATA(lv_gap_found) = abap_false.

        DO lv_batch_size TIMES.
          CLEAR: lt_tracking, lt_errors.
          DATA(lv_final_data_received) = abap_false.

          lv_current_ship_num = lv_current_ship_num + 1.
          ls_ship_key-shipment_reference = |000{ lv_current_ship_num }|.
          ls_ship_key-log_uuid = |{ cl_abap_context_info=>get_system_time( ) }|.
          ls_ship_key-trax_client = lv_trax_client.

          lv_message = |Querying for { ls_ship_key-shipment_reference }...|.
          lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'S' text = lv_message ) ).

          TRY.
              lo_qad_service->query_shipment_info(
                EXPORTING
                  iv_use_mock_data = abap_false
                IMPORTING
                  et_errors        = lt_errors
                CHANGING
                  cs_shipment_key  = ls_ship_key
              ).
              ls_ship_key-log_uuid = |{ cl_abap_context_info=>get_system_time( ) }|.

              IF lt_errors IS INITIAL.
                lv_final_data_received = abap_true.
              ELSE.
                lv_final_data_received = abap_false.
              ENDIF.

            CATCH zcx_qad_simple_error INTO DATA(lx_qad_error).
              lv_message = |!!! Critical polling error for { lx_qad_error->get_text( ) }|.
              lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'E' text = lv_message ) ).
              CONTINUE.
          ENDTRY.

          IF lv_final_data_received = abap_true.
            lv_message = |>>> Success: Final response received for { ls_ship_key-shipment_reference }|.
            lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'S' text = lv_message ) ).
          ELSE.
            lv_message = |>>> Gap found at { ls_ship_key-shipment_reference }. Stopping process.|.
            lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'W' text = lv_message ) ).
            lv_gap_found = abap_true.
            EXIT.
          ENDIF.

        ENDDO.

        IF lv_gap_found = abap_true.
          lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'S' text = 'Polling process finished due to gap.' ) ).
        ELSE.
          lo_log->add_item( cl_bali_free_text_setter=>create( severity = 'S' text = 'Polling process finished. Batch complete.' ) ).
        ENDIF.

      CATCH cx_bali_runtime INTO DATA(lx_bali).
    ENDTRY.

    IF lo_log IS BOUND.
      TRY.
          cl_bali_log_db=>get_instance( )->save_log(
              log                         = lo_log
              assign_to_current_appl_job  = abap_true
          ).
        CATCH cx_bali_runtime.
      ENDTRY.
    ENDIF.

  ENDMETHOD.


  METHOD if_apj_rt_run~get_text.
    rv_text = 'Poll QAD Shipment Status'.
  ENDMETHOD.
ENDCLASS.