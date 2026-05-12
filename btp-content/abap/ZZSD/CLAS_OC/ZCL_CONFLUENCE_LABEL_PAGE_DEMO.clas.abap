CLASS zcl_confluence_label_page_demo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ts_page_id,
        id TYPE string,
      END OF ts_page_id,
      tt_page_ids TYPE STANDARD TABLE OF ts_page_id WITH EMPTY KEY.

    TYPES:
      BEGIN OF ts_label_result,
        page_id TYPE string,
        labels  TYPE string_table,
        error   TYPE string,
      END OF ts_label_result,
      tt_label_results TYPE STANDARD TABLE OF ts_label_result WITH EMPTY KEY.

    METHODS:
      get_labels_for_pages
        IMPORTING
          it_page_ids      TYPE tt_page_ids
        RETURNING
          VALUE(rt_results) TYPE tt_label_results,
             get_pages_for_space
        IMPORTING
          it_page_ids      TYPE tt_page_ids
        RETURNING
          VALUE(rt_results) TYPE tt_label_results,
              add_labels_to_page
      IMPORTING
        iv_page_id       TYPE string
        it_labels        TYPE string_table
      RAISING
        cx_http_dest_provider_error
        cx_web_http_client_error
        cx_st_serialization_error.
    " --- END ADD ---

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ts_confluence_label,
        name TYPE string,
      END OF ts_confluence_label,
      tt_confluence_labels TYPE STANDARD TABLE OF ts_confluence_label WITH EMPTY KEY,

      BEGIN OF ts_confluence_response,
        results TYPE tt_confluence_labels,
      END OF ts_confluence_response.

      " --- ADD THESE TYPES ---
  TYPES:
    BEGIN OF ts_label_create_request,
      name TYPE string,
    END OF ts_label_create_request,
    tt_label_create_request TYPE STANDARD TABLE OF ts_label_create_request WITH EMPTY KEY.
  " --- END ADD ---

    METHODS:
      get_labels_for_page
        IMPORTING
          iv_page_id       TYPE string
        RETURNING
          VALUE(rt_labels) TYPE string_table
        RAISING
          cx_http_dest_provider_error
          cx_web_http_client_error
          cx_st_deserialization_error.

ENDCLASS.



CLASS ZCL_CONFLUENCE_LABEL_PAGE_DEMO IMPLEMENTATION.


  METHOD get_labels_for_pages.

    DATA ls_result LIKE LINE OF rt_results.

    LOOP AT it_page_ids INTO DATA(ls_page).
      ls_result-page_id = ls_page-id.

      TRY.
          ls_result-labels = get_labels_for_page( ls_page-id ).
          ls_result-error  = ''.
        " --- FIX: Catch all declared exceptions ---
        CATCH cx_http_dest_provider_error INTO DATA(lx_dest_error).
          ls_result-labels = VALUE #( ).
          ls_result-error  = lx_dest_error->get_text( ).
        CATCH cx_web_http_client_error INTO DATA(lx_http_error).
          ls_result-labels = VALUE #( ).
          ls_result-error  = lx_http_error->get_text( ).
        CATCH cx_st_deserialization_error INTO DATA(lx_json_error).
          ls_result-labels = VALUE #( ).
          ls_result-error  = lx_json_error->get_text( ).
      ENDTRY.

      INSERT ls_result INTO TABLE rt_results.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_pages_for_space.

    DATA: lo_http_client TYPE REF TO if_web_http_client,
          lo_destination TYPE REF TO if_http_destination,
          lo_request     TYPE REF TO if_web_http_request,
          lo_response    TYPE REF TO if_web_http_response,
          lv_json_data   TYPE string,
          lx_error       TYPE REF TO cx_root.

    TRY.
        " 1. Create HTTP client using the BTP Destination
        " --- THIS IS THE FIX ---
        " Use create_by_destination_NAME to read from BTP Destination Service
        lo_destination = cl_http_destination_provider=>create_by_cloud_destination( 'CamConJames' ).
        lo_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
        " --- END FIX ---

        " 2. Get the request object and set the path
        lo_request = lo_http_client->get_http_request( ).
        DATA(lv_path) = |/wiki/api/v2/spaces/C/pages|.
        lo_request->set_uri_path( lv_path ).
        " 3. Execute the GET request
        lo_response = lo_http_client->execute( if_web_http_client=>get ).

        " 4. Check for errors
        DATA(lv_status_code) = lo_response->get_status( )-code.
        IF lv_status_code <> 200.
          RAISE EXCEPTION TYPE cx_web_http_client_error.
        ENDIF.

        " 5. Get the JSON response body
        lv_json_data = lo_response->get_text( ).

        " 6. Parse the JSON response
        DATA ls_response TYPE ts_confluence_response.
        /ui2/cl_json=>deserialize(
          EXPORTING
            json   = lv_json_data
          CHANGING
            data = ls_response
        ).

        " 7. Extract the label names
        LOOP AT ls_response-results INTO DATA(ls_label).

        ENDLOOP.

      " --- FIX: Catch exceptions and re-raise them ---
      CATCH cx_http_dest_provider_error INTO lx_error.
        RAISE EXCEPTION lx_error.
      CATCH cx_web_http_client_error INTO lx_error.
        RAISE EXCEPTION lx_error.
      CATCH cx_st_deserialization_error INTO lx_error.
        RAISE EXCEPTION lx_error.
    ENDTRY.

    " 8. Close the connection
    lo_http_client->close( ).

  ENDMETHOD.


  METHOD get_labels_for_page.

    DATA: lo_http_client TYPE REF TO if_web_http_client,
          lo_destination TYPE REF TO if_http_destination,
          lo_request     TYPE REF TO if_web_http_request,
          lo_response    TYPE REF TO if_web_http_response,
          lv_json_data   TYPE string,
          lx_error       TYPE REF TO cx_root.

    TRY.
        " 1. Create HTTP client using the BTP Destination
        " --- THIS IS THE FIX ---
        " Use create_by_destination_NAME to read from BTP Destination Service
        lo_destination = cl_http_destination_provider=>create_by_cloud_destination( 'CamConJames' ).
        lo_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
        " --- END FIX ---

        " 2. Get the request object and set the path
        lo_request = lo_http_client->get_http_request( ).
        DATA(lv_path) = |/wiki/rest/api/content/{ iv_page_id }/label|.
        lo_request->set_uri_path( lv_path ).
        " 3. Execute the GET request
        lo_response = lo_http_client->execute( if_web_http_client=>get ).

        " 4. Check for errors
        DATA(lv_status_code) = lo_response->get_status( )-code.
        IF lv_status_code <> 200.
          RAISE EXCEPTION TYPE cx_web_http_client_error.
        ENDIF.

        " 5. Get the JSON response body
        lv_json_data = lo_response->get_text( ).

        " 6. Parse the JSON response
        DATA ls_response TYPE ts_confluence_response.
        /ui2/cl_json=>deserialize(
          EXPORTING
            json   = lv_json_data
          CHANGING
            data = ls_response
        ).

        " 7. Extract the label names
        LOOP AT ls_response-results INTO DATA(ls_label).
          INSERT ls_label-name INTO TABLE rt_labels.
        ENDLOOP.

      " --- FIX: Catch exceptions and re-raise them ---
      CATCH cx_http_dest_provider_error INTO lx_error.
        RAISE EXCEPTION lx_error.
      CATCH cx_web_http_client_error INTO lx_error.
        RAISE EXCEPTION lx_error.
      CATCH cx_st_deserialization_error INTO lx_error.
        RAISE EXCEPTION lx_error.
    ENDTRY.

    " 8. Close the connection
    lo_http_client->close( ).

  ENDMETHOD.


  METHOD add_labels_to_page.
    DATA: lo_http_client TYPE REF TO if_web_http_client,
            lo_destination TYPE REF TO if_http_destination,
            lo_request     TYPE REF TO if_web_http_request,
            lo_response    TYPE REF TO if_web_http_response,
            lx_error       TYPE REF TO cx_root.

  " 1. Prepare the JSON body
  DATA lt_label_request TYPE tt_label_create_request.
  LOOP AT it_labels INTO DATA(lv_label_name).
    INSERT VALUE #( name = lv_label_name ) INTO TABLE lt_label_request.
  ENDLOOP.


    DATA(lv_json_body) = /ui2/cl_json=>serialize(
      data        = lt_label_request
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case "
    ).

  TRY.
      " 2. Create HTTP client
      lo_destination = cl_http_destination_provider=>create_by_cloud_destination( 'CamConJames' ).
      lo_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

      " 3. Get request and set v1 path
      lo_request = lo_http_client->get_http_request( ).
      DATA(lv_path) = |/wiki/rest/api/content/{ iv_page_id }/label|.
      lo_request->set_uri_path( lv_path ).

      " 4. Set Body and Headers for POST
      lo_request->set_text( lv_json_body ).
      lo_request->set_header_field(
        i_name  = 'Content-Type'
        i_value = 'application/json'
      ).

      " 5. Execute the POST request
      lo_response = lo_http_client->execute( if_web_http_client=>post ).

      " 6. Check for errors (200 is success for this API)
      DATA(lv_status_code) = lo_response->get_status( )-code.
      DATA(lv_text) = lo_response->get_text( ).
      IF lv_status_code <> 200.
        RAISE EXCEPTION TYPE cx_web_http_client_error.
      ENDIF.

    CATCH cx_http_dest_provider_error INTO lx_error.
      RAISE EXCEPTION lx_error.
    CATCH cx_web_http_client_error INTO lx_error.
      RAISE EXCEPTION lx_error.
    CATCH cx_st_serialization_error INTO lx_error.
      RAISE EXCEPTION lx_error.
  ENDTRY.

  " 7. Close the connection
  IF lo_http_client IS BOUND.
    lo_http_client->close( ).
  ENDIF.
  ENDMETHOD.
ENDCLASS.