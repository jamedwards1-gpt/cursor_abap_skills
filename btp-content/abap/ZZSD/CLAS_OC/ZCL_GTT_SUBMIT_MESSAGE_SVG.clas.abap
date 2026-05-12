CLASS zcl_gtt_submit_message_svg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_gtt_message_data,
        " Add fields required to build your GTT message body
        " For example:
        shipment_reference TYPE string,
        vehicle_id         TYPE string,
      END OF ty_gtt_message_data.
    TYPES:
      BEGIN OF ty_error_message,
        type         TYPE c LENGTH 1,
        id           TYPE symsgid,
        number       TYPE symsgno,
        message      TYPE string,
        gtt_response TYPE string, " To hold the full GTT response on error
      END OF ty_error_message.
    TYPES tt_error_messages TYPE STANDARD TABLE OF ty_error_message WITH EMPTY KEY.

    METHODS submit_message
      IMPORTING
        is_message_data      TYPE ty_gtt_message_data
      EXPORTING
        et_errors            TYPE tt_error_messages
        ev_success           TYPE abap_bool
      RAISING
        zcx_qad_simple_error. " <<< Use a suitable exception class

  PRIVATE SECTION.
    CONSTANTS:
      " It is strongly recommended to move these to a secure parameter store,
      " not to keep them as constants in production code.
      BEGIN OF c_credentials,
        user TYPE string VALUE 'YOUR_API_USERNAME',
        pass TYPE string VALUE 'YOUR_API_PASSWORD',
      END OF c_credentials.

    METHODS build_gtt_request_xml
      IMPORTING
        is_message_data    TYPE ty_gtt_message_data
      RETURNING
        VALUE(rv_xml_string) TYPE string
      RAISING
        zcx_qad_simple_error.

    METHODS parse_gtt_response_xml
      IMPORTING
        iv_response_xml    TYPE string
      EXPORTING
        et_return_messages TYPE tt_error_messages
        ev_success         TYPE abap_bool
      RAISING
        zcx_qad_simple_error.

    METHODS call_gtt_api
      IMPORTING
        iv_request_xml     TYPE string
      RETURNING
        VALUE(rv_response_xml) TYPE string
      RAISING
        zcx_qad_simple_error.

    METHODS get_element_value
      IMPORTING
        io_parent_element TYPE REF TO if_ixml_element
        iv_name           TYPE string
      RETURNING
        VALUE(rv_value)   TYPE string.
ENDCLASS.



CLASS ZCL_GTT_SUBMIT_MESSAGE_SVG IMPLEMENTATION.


  METHOD build_gtt_request_xml.
    " This method builds the XML payload as required by the GTTE documentation.
    rv_xml_string = |<message>\n| &&
                    |  <header>\n| &&
                    |    <messageType>TE_SUBMIT_MESSAGE</messageType>\n| &&
                    |    <messageId>{ cl_system_uuid=>create_uuid_c32_static( ) }</messageId>\n| &&
                    |    <sender>YOUR_SENDER_ID</sender>\n| &&
                    |    <receiver>GTTE</receiver>\n| &&
                    |    <sendDate>{ CONV tstmpl( cl_abap_context_info=>get_system_timestamp( ) ) STYLE = xsd_date_time }\n</sendDate>\n| &&
                    |  </header>\n| &&
                    |  <body>\n| &&
                    |    <submission>\n| &&
                    "      \n| &&
                    "      \n| &&
                    |    </submission>\n| &&
                    |  </body>\n| &&
                    "  \n| &&
                    |  <security>\n| &&
                    |    <username>{ c_credentials-user }</username>\n| &&
                    |    <password>{ c_credentials-pass }</password>\n| &&
                    |  </security>\n| &&
                    |</message>|.
  ENDMETHOD.


  METHOD call_gtt_api.
    DATA lo_http_client      TYPE REF TO if_web_http_client.
    DATA lo_destination      TYPE REF TO if_http_destination.
    DATA lo_request          TYPE REF TO if_web_http_request.
    DATA lo_response         TYPE REF TO if_web_http_response.
    DATA(lv_destination_name) = 'QAD_QUERY_API_DEST'. " <<< Name of your Destination in BTP Cockpit
    DATA(lv_comm_arrangement) = 'YOUR_COMM_ARRANGEMENT_NAME'. " <<< CRITICAL: Your Arrangement Name here

    TRY.
        lo_destination = cl_http_destination_provider=>create_by_cloud_destination(
                           i_name                  = lv_destination_name
                           i_service_instance_name = lv_comm_arrangement " <<< This parameter is mandatory
                           i_authn_mode            = if_a4c_cp_service=>service_specific
                         ).

        lo_http_client = cl_web_http_manager=>create_by_http_destination( i_destination = lo_destination ).

        lo_request = lo_http_client->get_http_request( ).

        " <<< CRITICAL: Correct API path without the extra '/http'
        lo_request->set_uri_path( i_uri_path = '/highway/submitMessageAuthSecure' ).

        " <<< CRITICAL: Set Content-Type header as required by the API docs
        lo_request->set_header_field(
          name  = 'Content-Type'
          value = 'application/xml'
        ).

        lo_request->set_text( i_text = iv_request_xml ).

        lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).

        DATA(lv_status_code) = lo_response->get_status( )-code.
        rv_response_xml = lo_response->get_text( ).

        IF lv_status_code < 200 OR lv_status_code >= 300.
          RAISE EXCEPTION TYPE zcx_qad_simple_error
            EXPORTING message = |HTTP Error: { lv_status_code }. Response: { rv_response_xml }|.
        ENDIF.

      CATCH cx_root INTO DATA(lx_root_error).
        RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING previous = lx_root_error.
    FINALLY.
      IF lo_http_client IS BOUND.
        lo_http_client->close( ).
      ENDIF.
    ENDTRY.
  ENDMETHOD.


  METHOD get_element_value.
    DATA: lo_child_element TYPE REF TO if_ixml_element,
          lo_child_node    TYPE REF TO if_ixml_node.
    CLEAR rv_value.
    IF io_parent_element IS BOUND.
      lo_child_element = io_parent_element->find_from_name_ns( name = iv_name ).
      IF lo_child_element IS BOUND.
        lo_child_node = lo_child_element->get_first_child( ).
        IF lo_child_node IS BOUND AND lo_child_node->get_type( ) = if_ixml_node=>co_node_text.
          rv_value = lo_child_node->get_value( ).
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD parse_gtt_response_xml.
    DATA: lo_ixml_core        TYPE REF TO if_ixml_core,
          lo_document         TYPE REF TO if_ixml_document,
          lo_stream_factory   TYPE REF TO if_ixml_stream_factory_core,
          lo_istream          TYPE REF TO if_ixml_istream_core,
          lo_parser           TYPE REF TO if_ixml_parser_core.
    DATA  lv_response_xstring TYPE xstring.

    IF iv_response_xml IS INITIAL.
      RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'Received empty XML response for parsing.'.
    ENDIF.

    TRY.
        lv_response_xstring = cl_abap_conv_codepage=>create_out( codepage = 'UTF-8' )->convert( iv_response_xml ).

        lo_ixml_core = cl_ixml_core=>create( ).
        lo_stream_factory = lo_ixml_core->create_stream_factory( ).
        lo_istream = lo_stream_factory->create_istream_xstring( lv_response_xstring ).
        lo_document = lo_ixml_core->create_document( ).
        lo_parser = lo_ixml_core->create_parser( stream_factory = lo_stream_factory, istream = lo_istream, document = lo_document ).

        IF lo_parser->parse( ) <> 0.
          RAISE EXCEPTION TYPE zcx_gtt_simple_error EXPORTING message = |XML Parsing Error. Raw response: { iv_response_xml }|.
        ENDIF.

        DATA(lo_root_element) = lo_document->get_root_element( ).
        IF lo_root_element IS NOT BOUND OR lo_root_element->get_name( ) <> 'message'.
          RAISE EXCEPTION TYPE zcx_gtt_simple_error EXPORTING message = 'Response XML root element is not <message>.'.
        ENDIF.

        DATA(lo_body) = lo_root_element->find_from_name_ns( 'body' ).
        IF lo_body IS NOT BOUND.
          RAISE EXCEPTION TYPE zcx_gtt_simple_error EXPORTING message = 'Response XML does not contain a <body> element.'.
        ENDIF.

        " Assuming the response contains a <result> or <response> tag indicating status
        DATA(lv_result_code) = get_element_value( io_parent_element = lo_body, iv_name = 'resultCode' ). " Adjust tag name if needed
        DATA(lv_result_text) = get_element_value( io_parent_element = lo_body, iv_name = 'resultText' ). " Adjust tag name if needed

        IF lv_result_code = 'SUCCESS'. " <<< Adjust 'SUCCESS' value based on actual API response
          ev_success = abap_true.
          APPEND VALUE #( type = 'S' message = lv_result_text ) TO et_return_messages.
        ELSE.
          ev_success = abap_false.
          APPEND VALUE #( type         = 'E'
                          message      = |GTT API Error: { lv_result_text } (Code: { lv_result_code })|
                          gtt_response = iv_response_xml ) TO et_return_messages.
        ENDIF.

      CATCH cx_root INTO DATA(lx_parse_error).
        RAISE EXCEPTION TYPE zcx_gtt_simple_error EXPORTING previous = lx_parse_error
                                                      message = |Fatal error during XML parsing. Raw response: { iv_response_xml }|.
    ENDTRY.
  ENDMETHOD.


  METHOD submit_message.
    DATA lv_request_xml  TYPE string.
    DATA lv_response_xml TYPE string.

    CLEAR: et_errors, ev_success.

    TRY.
        lv_request_xml = build_gtt_request_xml( is_message_data ).
      CATCH zcx_qad_simple_error INTO DATA(lx_build_error).
        APPEND VALUE #( type = 'E' message = lx_build_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_build_error.
    ENDTRY.

    TRY.
        lv_response_xml = call_gtt_api( iv_request_xml = lv_request_xml ).
      CATCH zcx_qad_simple_error INTO DATA(lx_call_error).
        APPEND VALUE #( type = 'E' message = lx_call_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_call_error.
    ENDTRY.

    IF lv_response_xml IS INITIAL.
      RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'API call returned an empty response.'.
    ENDIF.

    TRY.
        parse_gtt_response_xml(
          EXPORTING
            iv_response_xml    = lv_response_xml
          IMPORTING
            et_return_messages = DATA(lt_parsed_errors)
            ev_success         = ev_success
        ).
        APPEND LINES OF lt_parsed_errors TO et_errors.
      CATCH zcx_qad_simple_error INTO DATA(lx_parse_error).
        APPEND VALUE #( type = 'E' message = lx_parse_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_parse_error.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.