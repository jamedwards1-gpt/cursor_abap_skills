CLASS zcl_transport_ui_static_json DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_transport_ui_static_json IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.

    DATA lv_method TYPE string.
    DATA lv_json   TYPE string.

    lv_method = request->get_method( ).

    IF lv_method <> 'GET'.
      response->set_status( i_code = if_web_http_status=>method_not_allowed ).
      response->set_header_field(
        i_name  = if_web_http_header=>content_type
        i_value = 'application/json; charset=utf-8' ).
      response->set_text( |\{ "error": "Only GET is supported" \}| ).
      RETURN.
    ENDIF.

    " Minimal static JSON. Publish as HTTP service in ADT (same pattern as ZCL_PARCEL_POLL_UI_HTTP).
    lv_json = |\{ "source": "ZCL_TRANSPORT_UI_STATIC_JSON", "ok": true, "hint": "Add HTTP service + communication scenario; open published URL or use transport-ui safe GET proxy." \}|.

    response->set_status( i_code = if_web_http_status=>ok ).
    response->set_header_field(
      i_name  = if_web_http_header=>content_type
      i_value = 'application/json; charset=utf-8' ).
    response->set_text( lv_json ).

  ENDMETHOD.

ENDCLASS.
