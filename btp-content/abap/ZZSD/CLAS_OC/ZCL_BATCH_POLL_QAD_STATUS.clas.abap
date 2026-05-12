CLASS zcl_batch_poll_qad_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_BATCH_POLL_QAD_STATUS IMPLEMENTATION.


METHOD if_oo_adt_classrun~main.

  DATA lv_message TYPE string.

  lv_message = |Polling process started at { cl_abap_context_info=>get_system_time( ) }|.
  out->write( lv_message ).
  out->write( '-------------------------------------------' ).

  "====================================================================
  " 1. Read all unprocessed shipment logs from the database
  "====================================================================
  SELECT *
    FROM zqad_poll_log
    WHERE status = 'SUBMITTED' OR status = 'POLLING'
    INTO TABLE @DATA(lt_poll_queue).

  IF sy-subrc <> 0 OR lt_poll_queue IS INITIAL.
    out->write( 'No shipments found in the queue to process.' ).
    RETURN.
  ENDIF.

  lv_message = |Found { lines( lt_poll_queue ) } shipment(s) to check.|.
  out->write( lv_message ).
  out->write( '-------------------------------------------' ).


  "====================================================================
  " 2. Instantiate the service and loop through the queue
  "====================================================================
  DATA(lo_qad_service) = NEW zcl_qad_queryshipment_svc( ).

  LOOP AT lt_poll_queue ASSIGNING FIELD-SYMBOL(<fs_log_entry>).

    DATA ls_ship_key TYPE zcl_qad_queryshipment_svc=>ty_qad_shipment_key.
    DATA lt_tracking TYPE zcl_qad_queryshipment_svc=>tt_qad_tracking_info.
    DATA lt_errors   TYPE zcl_qad_queryshipment_svc=>tt_error_messages.
    DATA lv_current_utclong TYPE utclong.

    lv_message = |Checking reference: { <fs_log_entry>-shipment_reference }|.
    out->write( lv_message ).

    ls_ship_key-shipment_reference = <fs_log_entry>-shipment_reference.
    ls_ship_key-trax_client        = 'UK1'.
    ls_ship_key-log_uuid           = <fs_log_entry>-shipment_uuid.

     out->write( '-------------------------------------------' ).
  ENDLOOP.

  out->write( 'Polling process finished.' ).

ENDMETHOD.
ENDCLASS.