CLASS zcl_parcel_qad_schedule DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_rt_run.
    INTERFACES if_apj_dt_defaults.

    DATA p_batch TYPE i.
    DATA p_client TYPE c LENGTH 3.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_parcel_qad_schedule IMPLEMENTATION.

  METHOD if_apj_dt_defaults~fill_attribute_defaults.
    p_batch = 5.
    p_client = 'UK1'.
  ENDMETHOD.

  METHOD if_apj_rt_run~execute.
    TRY.
        DATA lo_log TYPE REF TO if_bali_log.
        DATA lo_header TYPE REF TO if_bali_header_setter.
        DATA lv_batch_size TYPE i.
        DATA lv_trax_client TYPE string.
        DATA lo_qad_service TYPE REF TO zcl_parcel_qad_query.
        DATA lt_messages TYPE zcl_parcel_qad_query=>tt_run_messages.

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

        lv_batch_size = p_batch.
        lv_trax_client = p_client.

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

        lo_log->add_item( cl_bali_free_text_setter=>create(
          severity = if_bali_constants=>c_severity_status
          text     = |Processing trax client { lv_trax_client } with batch size { lv_batch_size }|
        ) ).

        CREATE OBJECT lo_qad_service.

        lo_qad_service->poll_pending_queue(
          EXPORTING
            iv_trax_client = lv_trax_client
            iv_max_items   = lv_batch_size
          IMPORTING
            et_messages    = lt_messages
        ).

        LOOP AT lt_messages ASSIGNING FIELD-SYMBOL(<fs_message>).
          lo_log->add_item( cl_bali_free_text_setter=>create(
            severity = COND #(
              WHEN <fs_message>-severity = 'E' THEN if_bali_constants=>c_severity_error
              WHEN <fs_message>-severity = 'W' THEN if_bali_constants=>c_severity_warning
              ELSE if_bali_constants=>c_severity_status
            )
            text     = CONV #( <fs_message>-text )
          ) ).
        ENDLOOP.

        CLEAR lt_messages.
        lo_qad_service->discover_shipments(
          EXPORTING
            iv_trax_client = lv_trax_client
            iv_max_items   = lv_batch_size
          IMPORTING
            et_messages    = lt_messages
        ).

        LOOP AT lt_messages ASSIGNING FIELD-SYMBOL(<fs_discover_message>).
          lo_log->add_item( cl_bali_free_text_setter=>create(
            severity = COND #(
              WHEN <fs_discover_message>-severity = 'E' THEN if_bali_constants=>c_severity_error
              WHEN <fs_discover_message>-severity = 'W' THEN if_bali_constants=>c_severity_warning
              ELSE if_bali_constants=>c_severity_status
            )
            text     = CONV #( <fs_discover_message>-text )
          ) ).
        ENDLOOP.

      CATCH cx_bali_runtime INTO DATA(lx_bali).
        IF lo_log IS BOUND.
          lo_log->add_item( cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_error
            text     = CONV #( lx_bali->get_text( ) )
          ) ).
        ENDIF.
    ENDTRY.

    IF lo_log IS BOUND.
      TRY.
          cl_bali_log_db=>get_instance( )->save_log(
            log                        = lo_log
            assign_to_current_appl_job = abap_true
          ).
        CATCH cx_bali_runtime.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD if_apj_rt_run~get_text.
    rv_text = 'Poll QAD Shipment Status'.
  ENDMETHOD.
ENDCLASS.
