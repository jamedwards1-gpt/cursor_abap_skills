CLASS zcl_run_confluence_demo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS ZCL_RUN_CONFLUENCE_DEMO IMPLEMENTATION.


 METHOD if_oo_adt_classrun~main.

  " 1. Create an instance of your class
  DATA(lo_api_caller) = NEW zcl_confluence_label_page_demo( ).

  "============================================
  "== TEST 1: GET LABELS (Your existing code)
  "============================================
  out->write( '--- STARTING TEST 1: GET LABELS ---' ).

  " !!! IMPORTANT: Change these to REAL page IDs from your Confluence !!!
  DATA(lt_get_pages) = VALUE zcl_confluence_label_page_demo=>tt_page_ids(
    ( id = '6418956404' )  " <-- Change this to a REAL page ID
    ( id = '425986' )  " <-- Change this to another REAL page ID
    ( id = '999999' )  " <-- This fake one will test errors
  ).


    DATA(lt_results) = lo_api_caller->get_pages_for_space( lt_get_pages ).
  out->write( '...Get labels call complete.' ).

  LOOP AT lt_results INTO DATA(ls_result).
    out->write( |Page ID: { ls_result-page_id }| ).
    IF ls_result-error IS INITIAL.
      out->write( '  Status: OK' ).
      out->write( '  Labels:' ).
      IF ls_result-labels IS initial.
        out->write( '    (No labels found)' ).
      ELSE.
        LOOP AT ls_result-labels INTO DATA(lv_label).
          out->write( |    - { lv_label }| ).
        ENDLOOP.
      ENDIF.
    ELSE.
      out->write( '  Status: ERROR' ).
      out->write( |  Message: { ls_result-error }| ).
    ENDIF.
    out->write( '---' ).
  ENDLOOP.


  "============================================
  "== TEST 2: ADD LABELS
  "============================================
  out->write( '--- STARTING TEST 2: ADD LABELS ---' ).

  " --- Define the page you want to add labels to ---
  " !!! IMPORTANT: Change this to a REAL page ID !!!
  DATA lv_target_page_id TYPE string.
lv_target_page_id = '557057'. " <-- Use a REAL page ID

  " --- Define the labels you want to add ---
  DATA(lt_labels_to_add) = VALUE string_table(
    ( `my-new-label` )
    ( `abap-test` )
  ).

  out->write( |Attempting to add labels to Page ID: { lv_target_page_id }...| ).
*  TRY.
*      " --- Call the ADD method ---
*      lo_api_caller->add_labels_to_page(
*        iv_page_id = lv_target_page_id
*        it_labels  = lt_labels_to_add
*      ).

*      out->write( '...SUCCESS: Labels added!' ).
*      out->write( 'Check your Confluence page to confirm.' ).
*
*    CATCH cx_root INTO DATA(lx_error).
*      " Catch any errors from the POST call
*      out->write( '...ERROR adding labels.' ).
*      out->write( |  Message: { lx_error->get_text( ) }| ).
*  ENDTRY.

  out->write( '--- ALL TESTS COMPLETE ---' ).

ENDMETHOD.
ENDCLASS.