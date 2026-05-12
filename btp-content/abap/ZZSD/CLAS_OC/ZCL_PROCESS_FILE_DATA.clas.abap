CLASS zcl_process_file_data DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: tt_messages TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.

    METHODS process_text_data
      IMPORTING
        it_file_lines      TYPE string_table
      RETURNING
        VALUE(rt_messages) TYPE tt_messages.

  PRIVATE SECTION.
    METHODS parse_line_and_call_fm
      IMPORTING
        iv_line         TYPE string
        iv_line_number  TYPE i
      CHANGING
        ct_messages     TYPE tt_messages.

    METHODS convert_string_to_date
      IMPORTING
        iv_date_string TYPE string
      RETURNING
        VALUE(rv_date) TYPE dats.

ENDCLASS.



CLASS ZCL_PROCESS_FILE_DATA IMPLEMENTATION.


METHOD convert_string_to_date.
    DATA lv_temp_yyyy_mm_dd_str TYPE string.
    DATA lv_check_date          TYPE d. " Helper variable of actual date type

    CLEAR rv_date. " Default to initial, rv_date is DATS (c(8))

    " If input is obviously initial or represents an initial date string, return initial.
    IF iv_date_string IS INITIAL OR iv_date_string = '00.00.0000'.
      RETURN. " rv_date is already initial
    ENDIF.

    " Check DD.MM.YYYY format
    IF strlen( iv_date_string ) = 10 AND
       iv_date_string+2(1) = '.' AND
       iv_date_string+5(1) = '.'.

      CONCATENATE iv_date_string+6(4) iv_date_string+3(2) iv_date_string+0(2) INTO lv_temp_yyyy_mm_dd_str.

      TRY.
          " Attempt to assign the YYYYMMDD string to a variable of type D.
          " If lv_temp_yyyy_mm_dd_str is not a valid date representation (e.g., '20230230', or non-numeric like 'ABC'),
          " lv_check_date will typically be set to '00000000' by the system, or a conversion error might occur.
          lv_check_date = lv_temp_yyyy_mm_dd_str.
        CATCH cx_sy_conversion_error.
          " This handles cases where the string cannot be converted to a date format at all (e.g., contains letters)
          CLEAR rv_date.
          RETURN.
      ENDTRY.

      " After assignment, if lv_check_date is '00000000' AND the input YYYYMMDD string
      " (lv_temp_yyyy_mm_dd_str) was not '00000000', it means the date was not plausible (e.g., 2023/02/30).
      IF lv_check_date = '00000000' AND lv_temp_yyyy_mm_dd_str <> '00000000'.
        CLEAR rv_date. " Not a valid calendar date, return initial for rv_date
        RETURN.
      ENDIF.

      " If we reach here, lv_check_date holds a valid calendar date,
      " and lv_temp_yyyy_mm_dd_str was its valid string form.
      " rv_date is of type DATS (which is c(8) and expects YYYYMMDD)
      rv_date = lv_temp_yyyy_mm_dd_str.

    ELSE.
      CLEAR rv_date. " Incorrect DD.MM.YYYY input format, return initial
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD parse_line_and_call_fm.
    DATA ls_upload_data TYPE zmy_new_table.
    DATA lt_components  TYPE string_table.
    DATA lv_component   TYPE string. " Helper variable for reading components
    DATA lv_success     TYPE abap_bool.
    DATA lt_fm_return   TYPE bapirettab.

    SPLIT iv_line AT cl_abap_char_utilities=>horizontal_tab INTO TABLE lt_components.

    IF lines( lt_components ) < 40. " Expecting at least 40 columns for ZMY_NEW_TABLE fields up to DATBI
      APPEND VALUE #( type = 'E' message = |Line { iv_line_number } has insufficient columns. Expected at least 40. Content: { iv_line }| ) TO ct_messages.
      RETURN.
    ENDIF.

    TRY.
        " Robustly read components and map
        " Index 1: CLIENT
        READ TABLE lt_components INDEX 1 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-client = |{ lv_component ALPHA = IN }|. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 2: ZZINDEX
        READ TABLE lt_components INDEX 2 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzindex = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 3: ZZMARKET_RESTYPE
        READ TABLE lt_components INDEX 3 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzmarket_restype = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 4: KOTABNR
        READ TABLE lt_components INDEX 4 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-kotabnr = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 5: MTART
        READ TABLE lt_components INDEX 5 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-mtart = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 6: ISMREFMDPRFAM
        READ TABLE lt_components INDEX 6 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-ismrefmdprfam = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 7: ISMREFMDPROD
        READ TABLE lt_components INDEX 7 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-ismrefmdprod = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 8: ZZMATNR
        READ TABLE lt_components INDEX 8 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzmatnr = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 9: IDENTCODE
        READ TABLE lt_components INDEX 9 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-identcode = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 10: ZZPUBL_FOR
        READ TABLE lt_components INDEX 10 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzpubl_for = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 11: ZZSPART
        READ TABLE lt_components INDEX 11 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzspart = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 12: ISMIMPRINT
        READ TABLE lt_components INDEX 12 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-ismimprint = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 13: ISMLANGUAGES
        READ TABLE lt_components INDEX 13 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-ismlanguages = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 14: ZZLANG_CODE
        READ TABLE lt_components INDEX 14 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzlang_code = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 15: ISMMEDIATYPE
        READ TABLE lt_components INDEX 15 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-ismmediatype = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 16: PRCTR
        READ TABLE lt_components INDEX 16 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-prctr = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 17: ZZPROD_ATTRIBUTE
        READ TABLE lt_components INDEX 17 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzprod_attribute = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 18: ZZHERKL
        READ TABLE lt_components INDEX 18 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzherkl = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 19: ISMEDITIONNUM
        READ TABLE lt_components INDEX 19 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-ismeditionnum = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 20: ZZEDITION_VER
        READ TABLE lt_components INDEX 20 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzedition_ver = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 21: ZZVKORG
        READ TABLE lt_components INDEX 21 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzvkorg = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 22: ZZKUNNR
        READ TABLE lt_components INDEX 22 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzkunnr = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 23: ZZLAND1
        READ TABLE lt_components INDEX 23 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzland1 = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 24: REGIO
        READ TABLE lt_components INDEX 24 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-regio = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 25: ZZKDGRP
        READ TABLE lt_components INDEX 25 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzkdgrp = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 26: KDKG4
        READ TABLE lt_components INDEX 26 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-kdkg4 = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 27: ZZKATR1
        READ TABLE lt_components INDEX 27 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzkatr1 = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 28: ZZLEA
        READ TABLE lt_components INDEX 28 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzlea = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 29: ZZSAN_FLG
        READ TABLE lt_components INDEX 29 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzsan_flg = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 30: ZLEGAL
        READ TABLE lt_components INDEX 30 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zlegal = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 31: EXCLUDE_BOM
        READ TABLE lt_components INDEX 31 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-exclude_bom = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 32: MATERIAL_EXCLUSION
        READ TABLE lt_components INDEX 32 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-material_exclusion = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 33: ZZREFERRAL
        READ TABLE lt_components INDEX 33 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzreferral = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 34: ZZEXCLUSION
        READ TABLE lt_components INDEX 34 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zzexclusion = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 35: ZZTEXTID
        READ TABLE lt_components INDEX 35 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zztextid = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 36: ZZTDNAME
        READ TABLE lt_components INDEX 36 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-zztdname = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 37: VALIDATE_BY
        READ TABLE lt_components INDEX 37 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-validate_by = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.
        " Index 38: VALIDATE_ON (CHAR10)
        READ TABLE lt_components INDEX 38 INTO lv_component.
        IF sy-subrc = 0. SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE. ls_upload_data-validate_on = lv_component. ELSE. RAISE EXCEPTION TYPE cx_sy_itab_line_not_found. ENDIF.

        " Index 39: DATAB (Date)
        DATA lv_datab_str TYPE string.
        READ TABLE lt_components INDEX 39 INTO lv_component.
        IF sy-subrc = 0.
          SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE.
          lv_datab_str = lv_component.
          ls_upload_data-datab = convert_string_to_date( iv_date_string = lv_datab_str ).
          IF ls_upload_data-datab IS INITIAL AND lv_datab_str IS NOT INITIAL AND lv_datab_str <> '00.00.0000'.
            APPEND VALUE #( type = 'E' message = |Invalid or unplausible date for DATAB: '{ lv_datab_str }' on line { iv_line_number }| ) TO ct_messages.
            RETURN. " Stop processing this line due to bad date
          ENDIF.
        ELSE.
          RAISE EXCEPTION TYPE cx_sy_itab_line_not_found.
        ENDIF.

        " Index 40: DATBI (Date)
        DATA lv_datbi_str TYPE string.
        READ TABLE lt_components INDEX 40 INTO lv_component.
        IF sy-subrc = 0.
          SHIFT lv_component LEFT DELETING LEADING SPACE. SHIFT lv_component RIGHT DELETING TRAILING SPACE.
          lv_datbi_str = lv_component.
          ls_upload_data-datbi = convert_string_to_date( iv_date_string = lv_datbi_str ).
          IF ls_upload_data-datbi IS INITIAL AND lv_datbi_str IS NOT INITIAL AND lv_datbi_str <> '00.00.0000'.
            APPEND VALUE #( type = 'E' message = |Invalid or unplausible date for DATBI: '{ lv_datbi_str }' on line { iv_line_number }| ) TO ct_messages.
            RETURN. " Stop processing this line due to bad date
          ENDIF.
        ELSE.
          RAISE EXCEPTION TYPE cx_sy_itab_line_not_found.
        ENDIF.

        CALL FUNCTION 'Z_ADD_ENTRIES'
          EXPORTING
            is_new_entry_data = ls_upload_data
          IMPORTING
            ev_success        = lv_success
            et_return         = lt_fm_return
          EXCEPTIONS
            insert_failed     = 1
            OTHERS            = 2.

        IF sy-subrc <> 0 OR lv_success = abap_false.
          IF lt_fm_return IS INITIAL.
            APPEND VALUE #( type = 'E' id = 'Z_UPLOAD_PROCESS' number = '001'
                            message = |FM Z_ADD_ENTRIES failed (SY-SUBRC { sy-subrc }) for line { iv_line_number }| ) TO ct_messages.
          ELSE.
            LOOP AT lt_fm_return ASSIGNING FIELD-SYMBOL(<fs_fm_return>).
              <fs_fm_return>-message = |Line { iv_line_number }: { <fs_fm_return>-message }|.
            ENDLOOP.
            APPEND LINES OF lt_fm_return TO ct_messages.
          ENDIF.
        ELSE.
          IF lt_fm_return IS NOT INITIAL.
            LOOP AT lt_fm_return ASSIGNING <fs_fm_return> WHERE type = 'S' OR type = 'I' OR type = 'W'.
              <fs_fm_return>-message = |Line { iv_line_number }: { <fs_fm_return>-message }|.
            ENDLOOP.
            APPEND LINES OF lt_fm_return TO ct_messages.
          ELSE.
             IF lv_success = abap_true.
                APPEND VALUE #( type = 'S' id = 'Z_UPLOAD_PROCESS' number = '002'
                                message = |Line { iv_line_number }: Successfully processed by FM.| ) TO ct_messages.
             ENDIF.
          ENDIF.
        ENDIF.

      CATCH cx_sy_assign_error INTO DATA(lx_assign).
        APPEND VALUE #( type = 'E' id = 'Z_UPLOAD_PROCESS' number = '003' message_v1 = lx_assign->get_text( ) message_v2 = |Line { iv_line_number }|
                        message = |Error assigning data: { lx_assign->get_text( ) } for line { iv_line_number }| ) TO ct_messages.
      CATCH cx_sy_conversion_error INTO DATA(lx_conv).
        APPEND VALUE #( type = 'E' id = 'Z_UPLOAD_PROCESS' number = '004' message_v1 = lx_conv->get_text( ) message_v2 = |Line { iv_line_number }|
                        message = |Error converting data: { lx_conv->get_text( ) } for line { iv_line_number }| ) TO ct_messages.
      CATCH cx_sy_itab_line_not_found.
        APPEND VALUE #( type = 'E' id = 'Z_UPLOAD_PROCESS' number = '005' message_v1 = |Line { iv_line_number }|
                        message = |Line { iv_line_number } component missing or read error. Content: { iv_line }| ) TO ct_messages.
    ENDTRY.
  ENDMETHOD.


  METHOD process_text_data.
    DATA lv_line_content TYPE string.
    DATA lv_is_header    TYPE abap_bool VALUE abap_true.
    DATA lv_line_number  TYPE i.

    LOOP AT it_file_lines INTO lv_line_content.
      lv_line_number = sy-tabix.

      IF lv_is_header = abap_true.
        lv_is_header = abap_false.
        CONTINUE. " Skip header row
      ENDIF.

      " TRIM lv_line_content
      SHIFT lv_line_content LEFT DELETING LEADING SPACE.
      SHIFT lv_line_content RIGHT DELETING TRAILING SPACE.

      IF lv_line_content IS INITIAL.
        APPEND VALUE #( type = 'W' message = |Skipping empty line at position: { lv_line_number }| ) TO rt_messages.
        CONTINUE. " Skip empty lines
      ENDIF.

      parse_line_and_call_fm(
        EXPORTING
          iv_line        = lv_line_content
          iv_line_number = lv_line_number
        CHANGING
          ct_messages    = rt_messages
      ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.