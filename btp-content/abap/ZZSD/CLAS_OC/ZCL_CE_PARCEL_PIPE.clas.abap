    CLASS zcl_ce_parcel_pipe DEFINITION
      PUBLIC
      FINAL
      CREATE PUBLIC.

      PUBLIC SECTION.
        INTERFACES if_rap_query_provider.

      PRIVATE SECTION.
        CONSTANTS gc_rfc_dest  TYPE string VALUE 'RFCcuperers_sapgw00'.
        CONSTANTS gc_rfc_fm    TYPE string VALUE 'ZBTP_PARCEL_EXTRACR'.
        CONSTANTS gc_delim     TYPE string VALUE '|'.

        TYPES tt_result TYPE STANDARD TABLE OF z_i_parcel_pipe WITH DEFAULT KEY.

        METHODS parse_csv
          IMPORTING iv_header        TYPE string
                    iv_csv           TYPE string
          RETURNING VALUE(rt_result) TYPE tt_result.

    ENDCLASS.


    CLASS zcl_ce_parcel_pipe IMPLEMENTATION.

      METHOD if_rap_query_provider~select.
        IF io_request->is_data_requested( ) = abap_false.
          RETURN.
        ENDIF.
        TRY.
            DATA(lo_dest)     = cl_rfc_destination_provider=>create_by_cloud_destination(
                                  i_name = gc_rfc_dest ).
            DATA(lv_destname) = lo_dest->get_destination_name( ).

            DATA lv_vbeln TYPE vbeln.
            TRY.
                DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
                READ TABLE lt_filter WITH KEY name = 'VBELN' INTO DATA(ls_f).
                IF sy-subrc = 0.
                  lv_vbeln = ls_f-range[ 1 ]-low.
                ENDIF.
              CATCH cx_root.
            ENDTRY.

            DATA: lv_csv    TYPE string,
                  lv_header TYPE string,
                  lv_count  TYPE i,
                  ls_return TYPE bapiret2.

            CALL FUNCTION gc_rfc_fm
              DESTINATION lv_destname
              EXPORTING  iv_vbeln         = lv_vbeln
              IMPORTING  ev_csv_data      = lv_csv
                         ev_fields_header = lv_header
                         ev_line_count    = lv_count
                         es_return        = ls_return.

            IF ls_return-type CA 'EA'.
              RETURN.
            ENDIF.

            DATA(lt_result) = parse_csv( iv_header = lv_header
                                         iv_csv    = lv_csv ).

            io_response->set_data( lt_result ).
            io_response->set_total_number_of_records( lines( lt_result ) ).

          CATCH cx_root.
        ENDTRY.
      ENDMETHOD.


      METHOD parse_csv.
        SPLIT iv_header AT gc_delim INTO TABLE DATA(lt_cols).
        DELETE lt_cols WHERE table_line IS INITIAL.

        SPLIT iv_csv AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_rows).

        LOOP AT lt_rows INTO DATA(lv_row).
          IF lv_row IS INITIAL. CONTINUE. ENDIF.

          SPLIT lv_row AT gc_delim INTO TABLE DATA(lt_vals).

          APPEND VALUE #(
            Vbeln      = VALUE #( lt_vals[ 1 ]  DEFAULT '' )
            Posnr      = VALUE #( lt_vals[ 2 ]  DEFAULT '' )
            SeqNum     = VALUE #( lt_vals[ 3 ]  DEFAULT '' )
            TrackNum   = VALUE #( lt_vals[ 4 ]  DEFAULT '' )
            Boxes      = VALUE #( lt_vals[ 5 ]  DEFAULT '' )
            CartonQty  = VALUE #( lt_vals[ 6 ]  DEFAULT '' )
            CartonWt   = VALUE #( lt_vals[ 7 ]  DEFAULT '' )
            Url        = VALUE #( lt_vals[ 8 ]  DEFAULT '' )
            DocketDate = VALUE #( lt_vals[ 9 ]  DEFAULT '' )
            Status     = VALUE #( lt_vals[ 10 ] DEFAULT '' )
          ) TO rt_result.
        ENDLOOP.
      ENDMETHOD.

    ENDCLASS.