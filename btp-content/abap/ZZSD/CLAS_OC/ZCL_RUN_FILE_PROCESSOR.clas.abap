CLASS zcl_run_file_processor DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_RUN_FILE_PROCESSOR IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    DATA ls_entry_to_add TYPE zmy_new_table. " This is the structure your FM expects
    DATA lv_fm_success   TYPE abap_bool.
    DATA lt_fm_return    TYPE bapirettab.
    DATA ls_fm_message   TYPE bapiret2.

    out->write( '--- Starting Test: Directly calling Z_ADD_ENTRIES FM ---' ).

    "--------------------------------------------------------------------"
    " Sample Record 1
    "--------------------------------------------------------------------"
    out->write( 'Preparing Sample Record 1...' ).
    CLEAR ls_entry_to_add. " Clear the structure before filling

    " Define each field value directly
    " Please adjust these values to be valid for your table and FM logic
    ls_entry_to_add-client            = sy-mandt.       " Or a specific client like '400'
    ls_entry_to_add-zzindex           = '0098520'.      " Key field
    ls_entry_to_add-zzmarket_restype  = 'B001'.
    ls_entry_to_add-kotabnr           = '548'.
    ls_entry_to_add-mtart             = 'FERT'.         " Example: Finished Product
    ls_entry_to_add-ismrefmdprfam     = 'FAMILY01'.
    ls_entry_to_add-ismrefmdprod      = 'PRODUCT01'.
    ls_entry_to_add-zzmatnr           = 'MAT0000001'.
    ls_entry_to_add-identcode         = 'ID00000001'.
    ls_entry_to_add-zzpubl_for        = 'PUB0000001'.
    ls_entry_to_add-zzspart           = '10'.
    ls_entry_to_add-ismimprint        = 'IMPRINT_A'.
    ls_entry_to_add-ismlanguages      = 'ENDE'.
    ls_entry_to_add-zzlang_code       = 'ENG'.
    ls_entry_to_add-ismmediatype      = 'BK'.          " Example: Book
    ls_entry_to_add-prctr             = 'PROFITC1'.
    ls_entry_to_add-zzprod_attribute  = 'ATTRIBUTE_X'.
    ls_entry_to_add-zzherkl           = 'DE'.
    ls_entry_to_add-ismeditionnum     = '000001'.
    ls_entry_to_add-zzedition_ver     = 'Version 1.0'.
    ls_entry_to_add-zzvkorg           = '1000'.
    ls_entry_to_add-zzkunnr           = 'CUST01'.
    ls_entry_to_add-zzland1           = 'DE'.
    ls_entry_to_add-regio             = '08'.          " Example: Baden-Württemberg
    ls_entry_to_add-zzkdgrp           = '01'.
    ls_entry_to_add-kdkg4             = 'A1'.
    ls_entry_to_add-zzkatr1           = 'B2'.
    ls_entry_to_add-zzlea             = '2700193469'.  " From your sample
    ls_entry_to_add-zzsan_flg         = 'X'.
    ls_entry_to_add-zlegal            = 'Y'.
    ls_entry_to_add-exclude_bom       = ' '.          " Space for not excluded, or 'X'
    ls_entry_to_add-material_exclusion = 'MATEXCL01'.
    ls_entry_to_add-zzreferral        = 'Z548'.        " From your sample
    ls_entry_to_add-zzexclusion       = 'Z548_002'.    " From your sample
    ls_entry_to_add-zztextid          = 'CARA DRAKE'.  " From your sample
    ls_entry_to_add-zztdname          = 'TDNAME_CD1'.  " Make sure this is appropriate
    ls_entry_to_add-validate_by       = 'BCOXWRIGHTSO'. " From your sample
    ls_entry_to_add-validate_on       = '01.07.2021'.  " CHAR(10), format DD.MM.YYYY is fine as string
    ls_entry_to_add-datab             = '20210701'.    " DATS type, requires YYYYMMDD format
    ls_entry_to_add-datbi             = '99991231'.    " DATS type, requires YYYYMMDD format
    " Your FM Z_ADD_ENTRIES will handle created_by, created_at, last_changed_by, etc.

    out->write( |Calling Z_ADD_ENTRIES for Record 1 (Index: { ls_entry_to_add-zzindex })...| ).
    CALL FUNCTION 'Z_ADD_ENTRIES'
      EXPORTING
        is_new_entry_data = ls_entry_to_add
      IMPORTING
        ev_success        = lv_fm_success
        et_return         = lt_fm_return
      EXCEPTIONS
        insert_failed     = 1
        OTHERS            = 2.

    IF sy-subrc = 0 AND lv_fm_success = abap_true.
      out->write( 'Record 1: FM executed successfully.' ).
    ELSE.
      out->write( |Record 1: FM execution FAILED. SY-SUBRC: { sy-subrc }, Success Flag: { lv_fm_success }| ).
    ENDIF.
    IF lt_fm_return IS NOT INITIAL.
      out->write( 'Messages from FM for Record 1:' ).
      LOOP AT lt_fm_return INTO ls_fm_message.
        out->write( |  Type: { ls_fm_message-type }, ID: { ls_fm_message-id }, Num: { ls_fm_message-number }, Text: { ls_fm_message-message }| ).
      ENDLOOP.
    ENDIF.
    CLEAR lt_fm_return. " Clear for next call


    "--------------------------------------------------------------------"
    " Sample Record 2 (Optional - add more if you want to test multiple)
    "--------------------------------------------------------------------"
    out->write( 'Preparing Sample Record 2...' ).
    CLEAR ls_entry_to_add.

    ls_entry_to_add-client            = sy-mandt.
    ls_entry_to_add-zzindex           = '0098521'.     " Different Key
    ls_entry_to_add-zzmarket_restype  = 'B002'.
    ls_entry_to_add-kotabnr           = '549'.
    ls_entry_to_add-mtart             = 'HALB'.         " Example: Semi-finished Product
    " ... Fill in other fields for record 2 with different data ...
    ls_entry_to_add-zzherkl           = 'US'.
    ls_entry_to_add-zzlea             = '2700193471'.
    ls_entry_to_add-datab             = '20220101'.
    ls_entry_to_add-datbi             = '20221231'.
    " ... ensure all required fields for your FM are populated ...

    out->write( |Calling Z_ADD_ENTRIES for Record 2 (Index: { ls_entry_to_add-zzindex })...| ).
    CALL FUNCTION 'Z_ADD_ENTRIES'
      EXPORTING
        is_new_entry_data = ls_entry_to_add
      IMPORTING
        ev_success        = lv_fm_success
        et_return         = lt_fm_return
      EXCEPTIONS
        insert_failed     = 1
        OTHERS            = 2.

    IF sy-subrc = 0 AND lv_fm_success = abap_true.
      out->write( 'Record 2: FM executed successfully.' ).
    ELSE.
      out->write( |Record 2: FM execution FAILED. SY-SUBRC: { sy-subrc }, Success Flag: { lv_fm_success }| ).
    ENDIF.
    IF lt_fm_return IS NOT INITIAL.
      out->write( 'Messages from FM for Record 2:' ).
      LOOP AT lt_fm_return INTO ls_fm_message.
        out->write( |  Type: { ls_fm_message-type }, ID: { ls_fm_message-id }, Num: { ls_fm_message-number }, Text: { ls_fm_message-message }| ).
      ENDLOOP.
    ENDIF.

    out->write( '--- Test Finished ---' ).

  ENDMETHOD.
ENDCLASS.