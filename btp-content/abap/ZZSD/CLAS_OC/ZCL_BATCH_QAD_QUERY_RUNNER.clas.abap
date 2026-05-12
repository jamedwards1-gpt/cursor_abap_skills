CLASS zcl_batch_qad_query_runner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_batch_qad_query_runner IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    CONSTANTS lc_trax_client TYPE string VALUE 'AU1'.
    CONSTANTS lc_batch_size TYPE i VALUE 5.

    DATA lo_qad_service TYPE REF TO zcl_qad_queryshipment_svc.
    DATA lt_messages TYPE zcl_qad_queryshipment_svc=>tt_run_messages.

    out->write( |Batch polling process started at { cl_abap_context_info=>get_system_time( ) } for { lc_trax_client }| ).
    out->write( '-------------------------------------------' ).

    CREATE OBJECT lo_qad_service.
    lo_qad_service->discover_shipments(
      EXPORTING
        iv_trax_client = lc_trax_client
        iv_max_items   = lc_batch_size
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
