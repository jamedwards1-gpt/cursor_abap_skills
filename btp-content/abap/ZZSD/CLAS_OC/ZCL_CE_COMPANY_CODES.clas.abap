CLASS zcl_ce_company_codes DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zcl_ce_company_codes IMPLEMENTATION.
METHOD if_rap_query_provider~select.
    " 1. Local Table Type for our CDS Entity
    TYPES tt_business_data TYPE STANDARD TABLE OF Z_I_CompanyCode WITH EMPTY KEY.

    " 2. Shadow Structure for BAPI_COMPANYCODE_GETLIST (List)
    TYPES: BEGIN OF ty_bapi_list,
             comp_code TYPE c LENGTH 4,
             comp_name TYPE c LENGTH 25,
           END OF ty_bapi_list.

    " 3. Shadow Structure for BAPI_COMPANYCODE_GETDETAIL (Full Fact Sheet)
    TYPES: BEGIN OF ty_bapi_detail,
             comp_code    TYPE c LENGTH 4,
             comp_name    TYPE c LENGTH 25,
             city         TYPE c LENGTH 25,
             country      TYPE c LENGTH 3,
             currency     TYPE c LENGTH 5,
             chart_of_acc TYPE c LENGTH 4,
             fisc_year_var TYPE c LENGTH 2,
             company      TYPE c LENGTH 6,
             field_0016   TYPE c LENGTH 4, " PostPeriodVar technical name
             vat_reg_no   TYPE c LENGTH 20,
           END OF ty_bapi_detail.

    DATA: lt_business_data TYPE tt_business_data,
          lt_bapi_list     TYPE STANDARD TABLE OF ty_bapi_list,
          ls_bapi_detail   TYPE ty_bapi_detail.

    " ... (The rest of your logic remains the same, just using these local types) ...

    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_top)    = lo_paging->get_page_size( ).
    DATA(lv_skip)   = lo_paging->get_offset( ).
    DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).

    IF io_request->is_data_requested( ).
      TRY.
          DATA(lo_dest) = cl_rfc_destination_provider=>create_by_cloud_destination( i_name = 'RFCcuperers_sapgw00' ).
          DATA(lv_dest_name) = lo_dest->get_destination_name( ).

          " Check if a specific CompanyCode is being requested (e.g. from a Fiori Object Page)
          READ TABLE lt_filter WITH KEY name = 'COMPANYCODE' INTO DATA(ls_filter_range).

          IF sy-subrc = 0 AND lines( ls_filter_range-range ) = 1.
            DATA(lv_sel_cc) = ls_filter_range-range[ 1 ]-low.

            CALL FUNCTION 'BAPI_COMPANYCODE_GETDETAIL'
              DESTINATION lv_dest_name
              EXPORTING
                companycodeid      =  lv_sel_cc
              IMPORTING
                companycode_detail = ls_bapi_detail.

            APPEND VALUE #(
              CompanyCode   = lv_sel_cc
              CompanyName   = ls_bapi_detail-comp_name
              City          = ls_bapi_detail-city
              Country       = ls_bapi_detail-country
              Currency      = ls_bapi_detail-currency
              ChartOfAccts  = ls_bapi_detail-chart_of_acc
              FiscalYearVar = ls_bapi_detail-fisc_year_var
              Company       = ls_bapi_detail-company
              VatRegNo      = ls_bapi_detail-vat_reg_no
            ) TO lt_business_data.

          ELSE.
            " Fallback to GetList if no specific code filtered
            CALL FUNCTION 'BAPI_COMPANYCODE_GETLIST'
              DESTINATION lv_dest_name
              TABLES
                companycode_list = lt_bapi_list.

            lt_business_data = VALUE #( FOR ls_list IN lt_bapi_list (
                                         CompanyCode = ls_list-comp_code
                                         CompanyName = ls_list-comp_name ) ).
          ENDIF.

          " --- Standard RAP Response Handling ---
          IF io_request->is_total_numb_of_rec_requested( ).
            io_response->set_total_number_of_records( lines( lt_business_data ) ).
          ENDIF.

          IF lv_top > 0 AND lv_top < lines( lt_business_data ).
            DATA(lt_paged) = VALUE tt_business_data( FOR i = lv_skip + 1 THEN i + 1
                               UNTIL i > lv_skip + lv_top OR i > lines( lt_business_data )
                               ( lt_business_data[ i ] ) ).
            io_response->set_data( lt_paged ).
          ELSE.
            io_response->set_data( lt_business_data ).
          ENDIF.

        CATCH cx_root INTO DATA(lx_err).
          " Error handling logic
      ENDTRY.
    ENDIF.
ENDMETHOD.
ENDCLASS.