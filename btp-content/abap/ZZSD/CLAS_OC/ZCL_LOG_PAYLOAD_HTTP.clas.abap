CLASS zcl_log_payload_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_LOG_PAYLOAD_HTTP IMPLEMENTATION.


  METHOD if_http_service_extension~handle_request.
    " 1. Get the incoming payload as a string
    DATA(lv_payload) = server->request->get_cdata( ).

    " 2. Log the payload using a simple logging utility
    " Note: For production, you might use a more robust logging framework like BAL.
    cl_abap_log=>add_text(
      text     = |Request Payload Received: { lv_payload }|
      severity = cl_abap_log=>severity_info
    ).

    " 3. Set the HTTP response status to 200 (OK)
    server->response->set_status( code = 200 reason = 'OK' ).

    " 4. (Optional) Set a simple response body
    server->response->set_cdata( 'Payload logged successfully.' ).
    server->response->set_header_field( name = 'Content-Type' value = 'text/plain' ).

  ENDMETHOD.
ENDCLASS.