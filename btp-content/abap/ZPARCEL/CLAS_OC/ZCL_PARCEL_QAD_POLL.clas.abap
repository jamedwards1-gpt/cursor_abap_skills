CLASS zcl_parcel_qad_poll DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_parcel_qad_poll IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    CONSTANTS lc_trax_client TYPE string VALUE 'UK1'.

    DATA lo_qad_service TYPE REF TO zcl_parcel_qad_query.
    DATA lt_messages TYPE zcl_parcel_qad_query=>tt_run_messages.

    out->write( |Polling process started at { cl_abap_context_info=>get_system_time( ) }| ).
    out->write( '-------------------------------------------' ).

    CREATE OBJECT lo_qad_service.
    lo_qad_service->poll_pending_queue(
      EXPORTING
        iv_trax_client = lc_trax_client
        iv_max_items   = 50
      IMPORTING
        et_messages    = lt_messages
    ).

    LOOP AT lt_messages ASSIGNING FIELD-SYMBOL(<fs_message>).
      out->write( |{ <fs_message>-severity }: { <fs_message>-text }| ).
    ENDLOOP.

    out->write( '-------------------------------------------' ).
    out->write( 'Polling process finished.' ).
  ENDMETHOD.
ENDCLASS.
