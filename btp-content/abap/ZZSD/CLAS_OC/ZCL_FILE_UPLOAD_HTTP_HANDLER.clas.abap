CLASS zcl_file_upload_http_handler DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_FILE_UPLOAD_HTTP_HANDLER IMPLEMENTATION.


  METHOD if_http_service_extension~handle_request.

    DATA lt_file_lines        TYPE string_table.
    DATA lo_file_processor    TYPE REF TO zcl_process_file_data.
    DATA lt_processing_messages TYPE zcl_process_file_data=>tt_messages.
    DATA lv_response_json     TYPE string.
    DATA lx_error             TYPE REF TO cx_root.

    " The 'request' and 'response' objects are provided by the IF_HTTP_SERVICE_EXTENSION interface.
    " We will use methods that ADT error messages suggest are available.

    " 1. Check if it's a POST request
    IF request->get_method( ) <> 'POST'. " get_method() is usually fine.
      response->set_status( i_code = if_web_http_status=>method_not_allowed ). " Using I_CODE as hinted
      response->set_header_field( i_name = if_web_http_header=>content_type i_value = 'text/plain' ). " Using I_NAME and IV_VALUE
      response->set_text( i_text = 'Error: Only POST method is allowed.' ). " Using SET_TEXT and IV_TEXT
      RETURN.
    ENDIF.

    " 2. Get the file content from the request body
    DATA(lv_request_body_string) = request->get_text( ). " get_text() was previously confirmed available by ADT hint

    IF lv_request_body_string IS INITIAL.
      response->set_status( i_code = if_web_http_status=>bad_request ). " Using I_CODE
      response->set_header_field( i_name = if_web_http_header=>content_type i_value = 'text/plain' ). " Using I_NAME and IV_VALUE
      response->set_text( i_text = 'Error: Request body is empty. Please provide file content.' ). " Using SET_TEXT and IV_TEXT
      RETURN.
    ENDIF.

    " 3. Split the raw string data into lines
    SPLIT lv_request_body_string AT cl_abap_char_utilities=>cr_lf INTO TABLE lt_file_lines.
    IF lt_file_lines IS INITIAL AND lv_request_body_string IS NOT INITIAL.
      CLEAR lt_file_lines.
      APPEND lv_request_body_string TO lt_file_lines.
    ENDIF.

    " 4. Process the data using your existing class ZCL_PROCESS_FILE_DATA
    TRY.
        CREATE OBJECT lo_file_processor.
        lt_processing_messages = lo_file_processor->process_text_data( it_file_lines = lt_file_lines ).

        " 5. Prepare the HTTP response as JSON using /UI2/CL_JSON
        TRY.
            lv_response_json = /ui2/cl_json=>serialize(
                                 data = lt_processing_messages
                                 compress = abap_false
                                 pretty_name = /ui2/cl_json=>pretty_mode-none
                               ).

            response->set_status( i_code = if_web_http_status=>ok ). " Using I_CODE
            response->set_header_field( i_name = if_web_http_header=>content_type i_value = 'application/json' ). " Using I_NAME and IV_VALUE
            response->set_text( i_text = lv_response_json ). " Using SET_TEXT and IV_TEXT

          CATCH cx_root INTO DATA(lx_json_serial_err). " Catch any serialization errors
            response->set_status( i_code = if_web_http_status=>internal_server_error ). " Using I_CODE
            response->set_header_field( i_name = if_web_http_header=>content_type i_value = 'text/plain' ). " Using I_NAME and IV_VALUE
            response->set_text( i_text = |Error during JSON response serialization: { lx_json_serial_err->get_text( ) }| ). " Using SET_TEXT and IV_TEXT
        ENDTRY.

      CATCH cx_root INTO lx_error. " Catch errors from ZCL_PROCESS_FILE_DATA
        response->set_status( i_code = if_web_http_status=>internal_server_error ). " Using I_CODE
        response->set_header_field( i_name = if_web_http_header=>content_type i_value = 'text/plain' ). " Using I_NAME and IV_VALUE
        response->set_text( i_text = |Error during file processing: { lx_error->get_text( ) }| ). " Using SET_TEXT and IV_TEXT
    ENDTRY.

  ENDMETHOD.
ENDCLASS.