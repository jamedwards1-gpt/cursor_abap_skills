CLASS zcl_btp_sync_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_btp_sync_test IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA: lv_csv        TYPE string,
          lv_header     TYPE string,
          lv_count      TYPE i,
          ls_return     TYPE bapiret2.

    out->write( |--- Starting Extraction for TVAP ---| ).

 TRY.
        " 1. Setup the Destination
          DATA(lo_dest) = cl_rfc_destination_provider=>create_by_cloud_destination( i_name = 'RFCcuperers_sapgw00' ).
          DATA(lv_dest_name) = lo_dest->get_destination_name( ).

        " 3. Call the Remote FM using the variable
        CALL FUNCTION 'ZBTP_CONFIG_EXTRACTOR_RAW'
          DESTINATION lv_dest_name
          EXPORTING
            iv_tabname       = 'TVAP'
            iv_delimiter     = '|'
          IMPORTING
            ev_csv_data      = lv_csv
            ev_fields_header = lv_header
            ev_line_count    = lv_count
            es_return        = ls_return.

        " 3. Handle Potential Errors (e.g., not in allowlist)
        IF ls_return-type = 'E'.
          out->write( |Error from ECC: { ls_return-message }| ).
          RETURN.
        ENDIF.

        " 4. Display Header and first few rows of data
        out->write( |Table: TVAP | ).
        out->write( |Columns: { lv_header }| ).
        out->write( |Total Records: { lv_count }| ).
        out->write( |--- Sample Data (First 5 Rows) ---| ).

        " 5. Dynamic JSON Construction
    out->write( |--- Converting to Dynamic JSON ---| ).

    SPLIT lv_header AT '|' INTO TABLE DATA(lt_cols).
    SPLIT lv_csv AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_rows).

    DATA(lv_json) = `[`.

    LOOP AT lt_rows INTO DATA(lv_row) FROM 1 TO 50. " Just the sample for now
      IF sy-tabix > 1. lv_json = lv_json && `,`. ENDIF.
      lv_json = lv_json && `{`.

      SPLIT lv_row AT '|' INTO TABLE DATA(lt_values).

      LOOP AT lt_cols INTO DATA(lv_col).
        " Get the value for this column index, or empty string if missing
        DATA(lv_val) = VALUE #( lt_values[ sy-tabix ] DEFAULT '' ).

        lv_json = lv_json && |"{ lv_col }":"{ lv_val }"|.

        IF sy-tabix < lines( lt_cols ).
          lv_json = lv_json && `,`.
        ENDIF.
      ENDLOOP.

      lv_json = lv_json && `}`.
    ENDLOOP.

    lv_json = lv_json && `]`.
    out->write( lv_json ).

      CATCH cx_root INTO DATA(lx_err).
        out->write( |Connection Error: { lx_err->get_text( ) }| ).
    ENDTRY.

    out->write( |--- Extraction Finished ---| ).
  ENDMETHOD.
ENDCLASS.