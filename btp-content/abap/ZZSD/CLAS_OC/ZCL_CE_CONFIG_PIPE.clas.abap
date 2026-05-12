CLASS zcl_ce_config_pipe DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zcl_ce_config_pipe IMPLEMENTATION.
  METHOD if_rap_query_provider~select.
    DATA: lt_result  TYPE STANDARD TABLE OF Z_I_ConfigPipe,
          lv_tabname TYPE c LENGTH 16,
          lv_csv     TYPE string,
          lv_header  TYPE string,
          lv_count   TYPE i,
          ls_return  TYPE bapiret2.

    " 1. Extract TableName from Filter/Key
   TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
        " Find the filter for TABLENAME
        READ TABLE lt_filter WITH KEY name = 'TABLENAME' INTO DATA(ls_tab_filter).
        IF sy-subrc = 0.
           lv_tabname = ls_tab_filter-range[ 1 ]-low.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    IF io_request->is_data_requested( ).
      TRY.
          " 2. RFC Call to ECC
          DATA(lo_dest) = cl_rfc_destination_provider=>create_by_cloud_destination( i_name = 'RFCcuperers_sapgw00' ).
          DATA(lv_dest_name) = lo_dest->get_destination_name( ).

          CALL FUNCTION 'ZBTP_CONFIG_EXTRACTOR_RAW'
            DESTINATION lv_dest_name
            EXPORTING iv_tabname = lv_tabname
            IMPORTING ev_csv_data = lv_csv
                      ev_fields_header = lv_header
                      ev_line_count = lv_count
                      es_return = ls_return.

 " --- 3. Build JSON Payload ---
        DATA(lv_delim) = '|'.

        " Split header into column names and remove empty trailing entries
        SPLIT lv_header AT lv_delim INTO TABLE DATA(lt_cols).
        DELETE lt_cols WHERE table_line IS INITIAL.

        " Split data into rows
        SPLIT lv_csv AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_rows).

        DATA(lv_json) = `[`.

        LOOP AT lt_rows INTO DATA(lv_row).
          " Skip the last empty line if it exists
          IF lv_row IS INITIAL. CONTINUE. ENDIF.

          " Add comma between JSON objects
          IF sy-tabix > 1. lv_json = lv_json && `,`. ENDIF.

          lv_json = lv_json && `{`.

          " Split the current data row
          SPLIT lv_row AT lv_delim INTO TABLE DATA(lt_vals).

          LOOP AT lt_cols INTO DATA(lv_col).
            DATA(lv_idx) = sy-tabix.

            " Map the value to the column technical name
            DATA(lv_val) = VALUE #( lt_vals[ lv_idx ] DEFAULT '' ).

            " Basic JSON escaping for internal quotes
            REPLACE ALL OCCURRENCES OF `"` IN lv_val WITH `\"`.

            " Concatenate "Key":"Value"
            lv_json = lv_json && |"{ lv_col }":"{ lv_val }"|.

            " Add comma if there are more columns to follow
            IF lv_idx < lines( lt_cols ).
              lv_json = lv_json && `,`.
            ENDIF.
          ENDLOOP.

          lv_json = lv_json && `}`.
        ENDLOOP.

        lv_json = lv_json && `]`.
        " -----------------------------

          " 4. Package Response
          APPEND VALUE #( TableName = lv_tabname
                          ConfigJson = lv_json
                          LineCount = lv_count ) TO lt_result.

          io_response->set_data( lt_result ).
          io_response->set_total_number_of_records( 1 ).

        CATCH cx_root. " Handle exceptions
      ENDTRY.
    ENDIF.
  ENDMETHOD.
ENDCLASS.