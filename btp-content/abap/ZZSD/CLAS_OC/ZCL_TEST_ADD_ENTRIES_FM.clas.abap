CLASS zcl_test_add_entries_fm DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_test_add_entries_fm IMPLEMENTATION.

METHOD if_oo_adt_classrun~main.
  " 1. Locally define the 512-character structure to mimic the backend 'WA'
  TYPES: BEGIN OF ty_wa,
           line TYPE c LENGTH 512,
         END OF ty_wa.

  " 2. Locally define the FIELD structure (since RFC_DB_FLD is restricted)
  TYPES: BEGIN OF ty_rfc_db_fld,
           fieldname TYPE c LENGTH 30,
           offset    TYPE c LENGTH 6,
           length    TYPE c LENGTH 6,
           type      TYPE c LENGTH 1,
           fieldtext TYPE c LENGTH 60,
         END OF ty_rfc_db_fld.

         TYPES: BEGIN OF ty_companycode_list,
           comp_code TYPE c LENGTH 4,
           comp_name TYPE c LENGTH 25,
         END OF ty_companycode_list.




  DATA: LT_COMPANYCODE_LIST   TYPE STANDARD TABLE OF ty_companycode_list, " This is now your 'Table of WA'
        lt_fields TYPE STANDARD TABLE OF ty_rfc_db_fld.
DATA: mystring type string.



  out->write( |Starting test with local 512-char WA structure...| ).

  TRY.
      DATA(lo_dest) = cl_rfc_destination_provider=>create_by_cloud_destination(
                        i_name = 'RFCcuperers_sapgw00'
                      ).
      DATA(lv_dest_name) = lo_dest->get_destination_name( ).


           CALL FUNCTION 'BAPI_COMPANYCODE_GETLIST'
        DESTINATION lv_dest_name
          TABLES
          COMPANYCODE_LIST = LT_COMPANYCODE_LIST.


      IF sy-subrc = 0.
        out->write( |Success! Rows returned: { lines( LT_COMPANYCODE_LIST ) }| ).
        LOOP AT LT_COMPANYCODE_LIST INTO DATA(ls_row).
           out->write( |{ ls_row-comp_code } - { ls_row-comp_name }| ).
        ENDLOOP.
      ELSE.
        out->write( |Failed with Subrc: { sy-subrc }| ).
      ENDIF.

    CATCH cx_root INTO DATA(lx_err).
      out->write( |Cloud Runtime Error: { lx_err->get_text( ) }| ).
  ENDTRY.
ENDMETHOD.
ENDCLASS.