CLASS zcl_qad_queryshipment_svc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_qad_shipment_key,
        trax_client         TYPE string,
        shipment_reference  TYPE string,
        erp_delivery_number TYPE vbeln,
        log_uuid            TYPE x LENGTH 16,
      END OF ty_qad_shipment_key.
    TYPES:
      BEGIN OF ty_qad_tracking_info,
        pack_number      TYPE string,
        track_num        TYPE string,
        url              TYPE string,
        carton_wt        TYPE string,
        carton_wt_uom    TYPE string,
        master_track_num TYPE string,
      END OF ty_qad_tracking_info.
    TYPES tt_qad_tracking_info TYPE STANDARD TABLE OF ty_qad_tracking_info WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_error_message,
        type             TYPE c LENGTH 1,
        id               TYPE symsgid,
        number           TYPE symsgno,
        message          TYPE string,
        qad_error_number TYPE string,
        qad_error_page   TYPE string,
        qad_error_table  TYPE string,
        qad_error_key    TYPE string,
        qad_action_seq   TYPE string,
        qad_action_type  TYPE string,
        qad_severity     TYPE string,
      END OF ty_error_message.
    TYPES tt_error_messages TYPE STANDARD TABLE OF ty_error_message WITH NON-UNIQUE KEY type.

  METHODS query_shipment_info
  IMPORTING
    iv_use_mock_data TYPE abap_bool DEFAULT abap_false
  EXPORTING
    et_tracking_info TYPE tt_qad_tracking_info
    et_errors        TYPE tt_error_messages
    CHANGING
    cs_shipment_key  TYPE ty_qad_shipment_key
  RAISING
    zcx_qad_simple_error.

    METHODS check_shipment_status
      IMPORTING
        is_shipment_key  TYPE ty_qad_shipment_key
      EXPORTING
        et_tracking_info TYPE tt_qad_tracking_info
        et_errors        TYPE tt_error_messages
      RAISING
        zcx_qad_simple_error.

  PRIVATE SECTION.
    METHODS build_qad_request_xml
      IMPORTING
        is_shipment_key    TYPE ty_qad_shipment_key
      RETURNING
        VALUE(rv_xml_string) TYPE string
      RAISING
        zcx_qad_simple_error.

    METHODS parse_qad_response_xml
      IMPORTING
        iv_response_xml      TYPE string
      EXPORTING
        et_tracking_info     TYPE tt_qad_tracking_info
        et_return_messages   TYPE tt_error_messages
      RAISING
        zcx_qad_simple_error.

    METHODS call_qad_api
      IMPORTING
        iv_request_xml       TYPE string
        iv_use_mock_data     TYPE abap_bool
      RETURNING
        VALUE(rv_response_xml) TYPE string
      RAISING
        zcx_qad_simple_error.

    METHODS get_mock_qad_response
      RETURNING
        VALUE(rv_mock_xml) TYPE string.

    METHODS get_mock_qad_error_response
      RETURNING
        VALUE(rv_mock_xml) TYPE string.

    METHODS get_element_value
      IMPORTING
        io_parent_element TYPE REF TO if_ixml_element
        iv_name           TYPE string
      RETURNING
        VALUE(rv_value)   TYPE string.

          METHODS escape_for_xml
    IMPORTING
      iv_unescaped_string TYPE string
    RETURNING
      VALUE(rv_escaped_string) TYPE string.

ENDCLASS.



CLASS ZCL_QAD_QUERYSHIPMENT_SVC IMPLEMENTATION.


  METHOD build_qad_request_xml.
    CONSTANTS:
      BEGIN OF lc_credentials,
        user TYPE string VALUE 'cup-api-test',
        pass TYPE string VALUE 'xeYKheH7oL92UPHt8S4E',
      END OF lc_credentials.

IF is_shipment_key-shipment_reference IS INITIAL.
    RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'ShipmentReference is missing for GTTE message'.
  ENDIF.

  " --- Step 1: Prepare all dynamic values in local variables first ---
  DATA lv_unique_message_id TYPE string.
  DATA lv_creation_datetime TYPE string.

  lv_unique_message_id = cl_system_uuid=>create_uuid_c22_static( ).

  DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
  DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
  lv_creation_datetime = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }T{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }Z|.

  " --- Step 2: Build the XML string using the prepared variables ---
        rv_xml_string =
      |<?xml version="1.0" encoding="UTF-8"?> | &
      |<QueryShipment xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="..\\Message_Schemas\\QueryShipment.xsd" lang="en-US" | &
      |environment="Quality" revision="S37">  | &
      |<ApplicationArea>    | &
      |<Sender>      | &
      |<LogicalId>LOG</LogicalId>      | &
      |<ReferenceId>MGA</ReferenceId>      | &
      |    <messageId>{ escape_for_xml( lv_unique_message_id ) }</messageId>| &
      |</Sender>    | &
      |    <sendDate>{ escape_for_xml( lv_creation_datetime ) }</sendDate>| &
      |</ApplicationArea>  | &
      |<DataArea>    | &
      |<Query confirm="Always"/>    | &
      |<Shipment>      | &
      |<TRAXClient>{ escape_for_xml( is_shipment_key-trax_client ) }</TRAXClient>      | &
      |<ShipmentReference>{ escape_for_xml( is_shipment_key-shipment_reference ) }</ShipmentReference>      | &
      |</Shipment>  | &
      |</DataArea>| &
      |</QueryShipment> | .


ENDMETHOD.


METHOD call_qad_api.
    IF iv_use_mock_data = abap_true.
      rv_response_xml = get_mock_qad_response( ).
      RETURN.
    ENDIF.

    DATA lo_http_client      TYPE REF TO if_web_http_client.
    DATA lv_destination_name TYPE string VALUE 'QADPrecision'.
    DATA lo_destination      TYPE REF TO if_http_destination.
    DATA lo_request          TYPE REF TO if_web_http_request.
    DATA lo_response         TYPE REF TO if_web_http_response.
    DATA lv_api_path         TYPE string.
    DATA lv_endpoint_id      TYPE string VALUE 'YourQadEndpointId'.

    lv_api_path = '/highway/http/SubmitMessageAuthSecure?Synchronous=Yes&HighwayMessageId=SPS_SHIP&HighwayEndpointId=SYNCH_IN&'.

    TRY.
        TRY.
            lo_destination = cl_http_destination_provider=>create_by_cloud_destination(
                               i_name = lv_destination_name
                             ).
          CATCH cx_root INTO DATA(lx_dest_prov_root_error).
            DATA(lv_dp_err_class_name) = cl_abap_classdescr=>get_class_name( lx_dest_prov_root_error ).
            RAISE EXCEPTION TYPE zcx_qad_simple_error
              EXPORTING previous = lx_dest_prov_root_error
                        message  = |Error creating destination '{ lv_destination_name }' ({ lv_dp_err_class_name }): { lx_dest_prov_root_error->get_text( ) }|.
        ENDTRY.

        IF lo_destination IS NOT BOUND.
          RAISE EXCEPTION TYPE zcx_qad_simple_error
            EXPORTING message = |Destination '{ lv_destination_name }' could not be created.|.
        ENDIF.

        lo_http_client = cl_web_http_client_manager=>create_by_http_destination( i_destination = lo_destination ).
        IF lo_http_client IS NOT BOUND.
          RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'Failed to create HTTP client from destination.'.
        ENDIF.

        TRY.
            lo_request = lo_http_client->get_http_request( ).
            IF lo_request IS NOT BOUND.
              RAISE EXCEPTION TYPE zcx_qad_simple_error
                EXPORTING message = 'get_http_request() returned an initial object. Check destination/client validity.'.
            ENDIF.
          CATCH cx_root INTO DATA(lx_get_request_error).
             RAISE EXCEPTION TYPE zcx_qad_simple_error
               EXPORTING previous = lx_get_request_error
                         message = |Error occurred during get_http_request(): { lx_get_request_error->get_text( ) }|.
        ENDTRY.

        lo_request->set_uri_path( i_uri_path = lv_api_path ).

        DATA(lv_xml_escaped) = cl_web_http_utility=>escape_url( unescaped = iv_request_xml ).
        DATA(lv_form_data)   = |HighwayEndpointId={ lv_endpoint_id }&HighwayMessage={ lv_xml_escaped }|.

        lo_request->set_header_field( i_name = if_web_http_header=>content_type
                                      i_value = 'application/x-www-form-urlencoded' ).

        lo_request->set_header_field( i_name = 'Synchronous'
                                      i_value = 'YES' ).

                lo_request->set_header_field( i_name = 'HighwayMessageId'
                                      i_value = 'SPS_RATE' ).

        lo_request->set_text( i_text = lv_form_data ).

        lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).

        IF lo_response IS NOT BOUND.
          RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'HTTP response object is initial after execute.'.
        ENDIF.

        DATA lo_status_obj    TYPE if_web_http_response=>http_status.
        DATA lv_status_code   TYPE i.
        DATA lv_reason_phrase TYPE string VALUE '(Reason phrase unavailable)'. " Default text

        lo_status_obj = lo_response->get_status( ). " Get the status object




        " Method get_status_reason() does not exist, so cannot retrieve it.

        rv_response_xml = lo_response->get_text( ).

        IF lo_status_obj-code <> 200.
          IF lo_http_client IS BOUND. lo_http_client->close( ). ENDIF.
          RAISE EXCEPTION TYPE zcx_qad_simple_error
            EXPORTING message = |HTTP Error: { lv_status_code } { lv_reason_phrase }. Response: { rv_response_xml }|.
        ENDIF.

        IF lo_http_client IS BOUND. lo_http_client->close( ). ENDIF.

      CATCH cx_web_http_client_error INTO DATA(lx_http_client_error).
        IF lo_http_client IS BOUND.
            TRY.
                lo_http_client->close( ).
              CATCH cx_web_http_client_error.
            ENDTRY.
        ENDIF.
        RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING previous = lx_http_client_error message = |HTTP Client Error: { lx_http_client_error->get_text( ) }|.
      CATCH cx_root INTO DATA(lx_root_error).
        IF lo_http_client IS BOUND.
            TRY.
                lo_http_client->close( ).
              CATCH cx_web_http_client_error.
            ENDTRY.
        ENDIF.
        DATA(lv_err_class_name) = cl_abap_classdescr=>get_class_name( lx_root_error ).
        RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING previous = lx_root_error message = |Unexpected Error ({ lv_err_class_name }): { lx_root_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD escape_for_xml.
  " This method manually escapes special XML characters to ensure compatibility.
  rv_escaped_string = iv_unescaped_string.
  REPLACE ALL OCCURRENCES OF '&' IN rv_escaped_string WITH '&amp;'.
  REPLACE ALL OCCURRENCES OF '<' IN rv_escaped_string WITH '&lt;'.
  REPLACE ALL OCCURRENCES OF '>' IN rv_escaped_string WITH '&gt;'.
  REPLACE ALL OCCURRENCES OF '"' IN rv_escaped_string WITH '&quot;'.
  REPLACE ALL OCCURRENCES OF '''' IN rv_escaped_string WITH '&apos;'.
ENDMETHOD.


  METHOD get_element_value.
    DATA lo_child_element TYPE REF TO if_ixml_element.
    DATA lo_child_node    TYPE REF TO if_ixml_node.
    CLEAR rv_value.
    IF io_parent_element IS BOUND.
      lo_child_element = io_parent_element->find_from_name_ns( name = iv_name uri = `` ).
      IF lo_child_element IS BOUND.
        lo_child_node = lo_child_element->get_first_child( ).
        IF lo_child_node IS BOUND AND ( lo_child_node->get_type( ) = if_ixml_node=>co_node_text OR lo_child_node->get_type( ) = if_ixml_node=>co_node_cdata_section ).
          rv_value = lo_child_node->get_value( ).
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


METHOD get_mock_qad_error_response.
    " This mock should mimic the overall ProcessSPSResponse structure,
    " but with the <Errors> section populated.
    rv_mock_xml =
        `<?xml version="1.0" encoding="UTF-8" ?>`
     && `<ProcessSPSResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="..\\Message_Schemas\\ProcessSPSResponse.xsd" lang="en-US" environment="Test" revision="S37">`
     &&   `<ApplicationArea><Sender><LogicalId>QAD_MOCK</LogicalId></Sender><CreationDateTime>2023-05-23T12:00:00Z</CreationDateTime></ApplicationArea>`
     &&   `<DataArea>`
     &&     `<Process confirm="Always" />`
     &&     `<SPSResponse>`
     &&       `<OriginalMessage><Type>QueryShipment</Type><OriginalMessageId>MOCK_ERR_MSG_001</OriginalMessageId></OriginalMessage>`
     &&       `<TRAXClient>MOCKCL</TRAXClient>`
     &&       `<ShipmentReference>MOCK_SHIP_ERR_001</ShipmentReference>`
     &&       `<Tracking></Tracking>` " Empty tracking for error case perhaps
     &&       `<Errors>`
     &&         `<Error>`
     &&           `<ErrorNumber>QAD001</ErrorNumber>`
     &&           `<ErrorText>Mocked QAD Processing Error Text</ErrorText>`
     &&           `<ErrorPageURL>http://qad.com/error/QAD001</ErrorPageURL>`
     &&           `<ErrorTable>XMSHDR0</ErrorTable>`
     &&           `<ErrorTableKey>KEY123</ErrorTableKey>`
     &&           `<Action><Sequence>10</Sequence><Type>VALIDATE</Type><Severity>ERROR</Severity></Action>`
     &&         `</Error>`
     &&         `<Error>`
     &&           `<ErrorNumber>GEN002</ErrorNumber>`
     &&           `<ErrorText>Another Mocked Error</ErrorText>`
     &&         `</Error>`
     &&       `</Errors>`
     &&     `</SPSResponse>`
     &&   `</DataArea>`
     && `</ProcessSPSResponse>`.
  ENDMETHOD.


   METHOD get_mock_qad_response.
     " Unchanged from your last provided version, this is fine
    rv_mock_xml =
        `<?xml version="1.0" encoding="UTF-8" ?>`
    && `<ProcessSPSResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="..\\Message_Schemas\\ProcessSPSResponse.xsd" lang="en-US" environment="Test" revision="S37">`
    &&   `<ApplicationArea><Sender><LogicalId>QAD_MOCK</LogicalId></Sender><CreationDateTime>2023-05-23T12:00:00Z</CreationDateTime></ApplicationArea>`
    &&   `<DataArea>`
    &&     `<Process confirm="Always" />`
    &&     `<SPSResponse>`
    &&       `<OriginalMessage><Type>QueryShipment</Type><OriginalMessageId>MOCK_MSG_001</OriginalMessageId></OriginalMessage>`
    &&       `<TRAXClient>MOCKCL</TRAXClient>`
    &&       `<ShipmentReference>MOCK_SHIP_REF_001</ShipmentReference>`
    &&       `<Tracking>`
    &&         `<TrackingDetails>`
    &&           `<PackNumber>PKG001</PackNumber>`
    &&           `<TrackingNumber>TRACK12345XYZ</TrackingNumber>`
    &&           `<MasterTrackingNumber>MASTERTRACK987</MasterTrackingNumber>`
    &&           `<TrackingURL>http://example.com/track?id=TRACK12345XYZ</TrackingURL>`
    &&           `<PackWeight><UOM>KG</UOM><Weight>10.5</Weight></PackWeight>`
    &&         `</TrackingDetails>`
    &&       `</Tracking>`
    &&       `<Errors/>`
    &&     `</SPSResponse>`
    &&   `</DataArea>`
    && `</ProcessSPSResponse>`.
  ENDMETHOD.


METHOD parse_qad_response_xml.
  DATA: lo_ixml_core         TYPE REF TO if_ixml_core,
        lo_document          TYPE REF TO if_ixml_document,
        lo_stream_factory    TYPE REF TO if_ixml_stream_factory_core,
        lo_istream           TYPE REF TO if_ixml_istream_core,
        lo_parser            TYPE REF TO if_ixml_parser_core,
        lv_response_xstring  TYPE xstring,
        lv_root_string       TYPE xstring.

  IF iv_response_xml IS INITIAL.
    RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'Received empty XML response for parsing.'.
  ENDIF.

  TRY.
      lv_response_xstring = cl_abap_conv_codepage=>create_out( codepage = 'UTF-8' )->convert( iv_response_xml ).

      lo_ixml_core      = cl_ixml_core=>create( ).
      lo_stream_factory = lo_ixml_core->create_stream_factory( ).
      lo_document       = lo_ixml_core->create_document( ).
      lo_istream        = lo_stream_factory->create_istream_xstring( string = lv_response_xstring ).
      lo_parser         = lo_ixml_core->create_parser( stream_factory = lo_stream_factory istream = lo_istream document = lo_document ).

      IF lo_parser->parse( ) <> 0.
        RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'XML Parser returned a non-zero code'.
      ENDIF.

      DATA(lo_root_element) = lo_document->get_root_element( ).
      IF lo_root_element IS NOT BOUND.
        RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'Could not find root element in response.'.
      ENDIF.

      DATA(lv_root_name) = lo_root_element->get_name( ).

      " <<< FIX: Handle the different types of XML response from the server >>>
      CASE lv_root_name.
        WHEN 'Highway'.
                lv_root_string  = lo_root_element->get_content_as_string(  ).
          " This is a status receipt from the middleware, not the final data.
          " We extract the comment and return it as a Warning message.
          DATA(lv_comment) = get_element_value( io_parent_element = lo_root_element iv_name = 'Comment' ).
          DATA(lv_status)  = get_element_value( io_parent_element = lo_root_element iv_name = 'com.precisionsoftware.highway.ui.web.HttpsAuthReader' ).

          APPEND VALUE #( type = 'W' message = |Highway Status: { lv_status } Comment: { lv_comment }| ) TO et_return_messages.

        WHEN 'ProcessSPSResponse'.
          " This is the real business data response. Proceed with your original detailed parsing.
          DATA(lo_data_area) = lo_root_element->find_from_name_ns( name = 'DataArea' ).
          IF lo_data_area IS NOT BOUND.
            RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'DataArea element not found in ProcessSPSResponse.'.
          ENDIF.

          DATA(lo_sps_response_data) = lo_data_area->find_from_name_ns( name = 'SPSResponse' ).
          IF lo_sps_response_data IS NOT BOUND.
            RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'SPSResponse element not found in DataArea.'.
          ENDIF.

          " Your original parsing logic for <Errors> and <Tracking> goes here.
          " This part of your code is correct for handling the ProcessSPSResponse document.
          DATA(lo_errors_node) = lo_sps_response_data->find_from_name_ns( name = 'Errors' ).
          IF lo_errors_node IS BOUND.
            " ... your loop over the errors ...
          ENDIF.


            DATA(lo_tracking_node) = lo_sps_response_data->find_from_name_ns( name = 'Tracking' ).
            IF lo_tracking_node IS BOUND.
" This block executes when the query is successful (no 'E' type errors).
          IF NOT line_exists( et_return_messages[ type = 'E' ] ).

            "====================================================================
            " 1. POPULATE HEADER TABLE (ZPAR_TRC_H)
            "====================================================================
            DATA ls_trc_h TYPE zpar_trc_h.
            ls_trc_h-client = sy-mandt.

            " Get header-level fields from <SPSResponse>
            ls_trc_h-qad_shipment_ref    = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'ShipmentReference' ).
            ls_trc_h-shipper_id          = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'Shipper' ).
            ls_trc_h-trax_client         = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'TRAXClient' ).
            ls_trc_h-service_code        = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'Service' ).
            ls_trc_h-global_carrier_code = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'GlobalCarrierCode' ).

            " Get and format the date (YYYY-MM-DDTHH:MM:SS -> YYYYMMDD)
            DATA(lv_despatch_date_str) = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'DespatchDate' ).
            IF strlen( lv_despatch_date_str ) >= 10.
              REPLACE ALL OCCURRENCES OF '-' IN lv_despatch_date_str WITH ''.
              ls_trc_h-despatch_date = lv_despatch_date_str(8).
            ENDIF.

            " Get nested OrderReference (ERP Delivery Number)
            DATA(lo_items_node) = lo_sps_response_data->find_from_name_ns( name = 'Items' ).
            IF lo_items_node IS BOUND.
              DATA(lo_item_node) = lo_items_node->find_from_name_ns( name = 'Item' ).
              IF lo_item_node IS BOUND.
                DATA(lo_references_node) = lo_item_node->find_from_name_ns( name = 'References' ).
                IF lo_references_node IS BOUND.
                  ls_trc_h-erp_delivery_number = get_element_value( io_parent_element = lo_references_node iv_name = 'OrderReference' ).
                ENDIF.
              ENDIF.
            ENDIF.

            " Get nested Total Charge
            DATA(lo_charge_total_node) = lo_sps_response_data->find_from_name_ns( name = 'ChargeTotal' ).
            IF lo_charge_total_node IS BOUND.
              DATA(lo_sell_amount_node) = lo_charge_total_node->find_from_name_ns( name = 'SellAmount' ).
              IF lo_sell_amount_node IS BOUND.
                ls_trc_h-total_charge_sell = get_element_value( io_parent_element = lo_sell_amount_node iv_name = 'Value' ).
                ls_trc_h-currency_code     = get_element_value( io_parent_element = lo_sell_amount_node iv_name = 'Currency' ).
              ENDIF.
            ENDIF.

            " Perform the database update for the header table
            IF ls_trc_h-erp_delivery_number IS NOT INITIAL AND ls_trc_h-qad_shipment_ref IS NOT INITIAL.
              " Using MODIFY for safety - it will UPDATE if the record exists, or INSERT if it's new.
              MODIFY zpar_trc_h FROM @ls_trc_h.
            ENDIF.


            "====================================================================
            " 2. POPULATE PACKAGE TABLE (ZPAR_TRC_P) & EXPORTING PARAMETER
            "====================================================================
            DATA lt_trc_p TYPE STANDARD TABLE OF zpar_trc_p.
            lo_tracking_node = lo_sps_response_data->find_from_name_ns( name = 'Tracking' ).
            IF lo_tracking_node IS BOUND.
              DATA(lo_tracking_details_nodelist) = lo_tracking_node->get_elements_by_tag_name_ns( name = 'TrackingDetails' uri = `` ).
              DATA lo_current_td_node TYPE REF TO if_ixml_node.

              DO lo_tracking_details_nodelist->get_length( ) TIMES.
                lo_current_td_node = lo_tracking_details_nodelist->get_item( sy-index - 1 ).
                IF lo_current_td_node IS BOUND AND lo_current_td_node->get_type( ) = if_ixml_node=>co_node_element.
                  DATA(lo_td_element) = CAST if_ixml_element( lo_current_td_node ).

                  " 2a: Populate the et_tracking_info exporting table (your existing logic)
                  APPEND INITIAL LINE TO et_tracking_info ASSIGNING FIELD-SYMBOL(<fs_track_info>).
                  <fs_track_info>-pack_number      = get_element_value( io_parent_element = lo_td_element iv_name = 'PackNumber' ).
                  <fs_track_info>-track_num        = get_element_value( io_parent_element = lo_td_element iv_name = 'TrackingNumber' ).
                  <fs_track_info>-master_track_num = get_element_value( io_parent_element = lo_td_element iv_name = 'MasterTrackingNumber' ).
                  <fs_track_info>-url              = get_element_value( io_parent_element = lo_td_element iv_name = 'TrackingURL' ).
                  DATA(lo_pack_weight) = lo_td_element->find_from_name_ns( name = 'PackWeight' ).
                  IF lo_pack_weight IS BOUND.
                    <fs_track_info>-carton_wt     = get_element_value( io_parent_element = lo_pack_weight iv_name = 'Weight' ).
                    <fs_track_info>-carton_wt_uom = get_element_value( io_parent_element = lo_pack_weight iv_name = 'UOM' ).
                  ENDIF.

                  " 2b: Populate the new ZPAR_TRC_P package table
                  APPEND INITIAL LINE TO lt_trc_p ASSIGNING FIELD-SYMBOL(<fs_pkg>).
                  <fs_pkg>-client               = sy-mandt.
                  <fs_pkg>-erp_delivery_number  = ls_trc_h-erp_delivery_number.
                  <fs_pkg>-qad_shipment_ref     = ls_trc_h-qad_shipment_ref.
                  <fs_pkg>-pack_number          = <fs_track_info>-pack_number.
                  <fs_pkg>-tracking_number      = <fs_track_info>-track_num.
                  <fs_pkg>-master_tracking_number = <fs_track_info>-master_track_num.
                  <fs_pkg>-weight               = <fs_track_info>-carton_wt.
                  <fs_pkg>-weight_uom           = <fs_track_info>-carton_wt_uom.

                ENDIF.
              ENDDO.

              " 2c: Perform the database update for the package table
              IF lt_trc_p IS NOT INITIAL.
                " Delete existing packages for this shipment first, then insert the new set
                DELETE FROM zpar_trc_p WHERE erp_delivery_number = @ls_trc_h-erp_delivery_number
                                          AND qad_shipment_ref = @ls_trc_h-qad_shipment_ref.
                INSERT zpar_trc_p FROM TABLE @lt_trc_p.
              ENDIF.

            ENDIF. " End IF lo_tracking_node IS BOUND
          ENDIF. " End IF NOT line_exists( errors )

            ENDIF.


        WHEN OTHERS.
          " The response was valid XML, but with an unknown root element.
          RAISE EXCEPTION TYPE zcx_qad_simple_error
            EXPORTING message = |Unexpected XML root element received: '{ lv_root_name }'|.
      ENDCASE.

    CATCH cx_root INTO DATA(lx_ixml_error).
      RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING previous = lx_ixml_error.
  ENDTRY.
ENDMETHOD.


METHOD query_shipment_info.
  DATA lv_request_xml  TYPE string.
  DATA lv_response_xml TYPE string.

  " Use a local variable for the key data.
  DATA ls_local_ship_key LIKE cs_shipment_key.
  ls_local_ship_key = cs_shipment_key.

  " Generate the unique ID and pass it back to the caller via the CHANGING parameter.
  ls_local_ship_key-log_uuid = cl_system_uuid=>create_uuid_x16_static( ).
  cs_shipment_key-log_uuid   = ls_local_ship_key-log_uuid.

  CLEAR: et_tracking_info, et_errors.

  " <<< FINAL FIX: Corrected typo in method call >>>
  DATA lv_current_utclong TYPE utclong.
  CALL METHOD cl_abap_utclong=>from_system_timestamp
    EXPORTING
      system_date = cl_abap_context_info=>get_system_date( )
      system_time = cl_abap_context_info=>get_system_time( )   " FIX: Corrected typo from cl_abab_...
    IMPORTING
      utc_tstmp = lv_current_utclong.

  DATA(ls_log_entry) = VALUE zqad_poll_log(
    client                = sy-mandt
    shipment_uuid         = ls_local_ship_key-log_uuid
    shipment_reference    = ls_local_ship_key-shipment_reference
    status                = 'SUBMITTED'
    poll_count            = 0
    created_at            = lv_current_utclong
    last_changed_at       = lv_current_utclong
    local_last_changed_at = lv_current_utclong
  ).
  INSERT zqad_poll_log FROM @ls_log_entry.

  TRY.
      lv_request_xml = build_qad_request_xml( ls_local_ship_key ).
    CATCH zcx_qad_simple_error INTO DATA(lx_build_error).
      APPEND VALUE #( type = 'E' message = lx_build_error->get_text( ) ) TO et_errors.
      RAISE EXCEPTION lx_build_error.
  ENDTRY.

  TRY.
      lv_response_xml = call_qad_api( iv_request_xml   = lv_request_xml
                                      iv_use_mock_data = iv_use_mock_data ).
    CATCH zcx_qad_simple_error INTO DATA(lx_call_error).
      APPEND VALUE #( type = 'E' message = lx_call_error->get_text( ) ) TO et_errors.
      RAISE EXCEPTION lx_call_error.
  ENDTRY.

  IF iv_use_mock_data = abap_false AND lv_response_xml IS INITIAL.
    RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'Submission API call returned an empty response.'.
  ENDIF.

  TRY.
      parse_qad_response_xml(
        EXPORTING
          iv_response_xml    = lv_response_xml
        IMPORTING
          et_tracking_info   = et_tracking_info
          et_return_messages = DATA(lt_parsed_errors) ).
      APPEND LINES OF lt_parsed_errors TO et_errors.
    CATCH zcx_qad_simple_error INTO DATA(lx_parse_error).
      APPEND VALUE #( type = 'E' message = lx_parse_error->get_text( ) ) TO et_errors.
      RAISE EXCEPTION lx_parse_error.
  ENDTRY.
ENDMETHOD.


  METHOD check_shipment_status.
    DATA lv_request_xml  TYPE string.
    DATA lv_response_xml TYPE string.

    CLEAR: et_tracking_info, et_errors.

    TRY.
   "     lv_request_xml = build_query_request_xml( is_shipment_key ).
      CATCH zcx_qad_simple_error INTO DATA(lx_build_error).
        APPEND VALUE #( type = 'E' message = lx_build_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_build_error.
    ENDTRY.

    TRY.
        lv_response_xml = call_qad_api( iv_request_xml   = lv_request_xml
                                        iv_use_mock_data = abap_false ).
      CATCH zcx_qad_simple_error INTO DATA(lx_call_error).
        APPEND VALUE #( type = 'E' message = lx_call_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_call_error.
    ENDTRY.

    IF lv_response_xml IS INITIAL.
      RAISE EXCEPTION TYPE zcx_qad_simple_error EXPORTING message = 'Query API call returned an empty response.'.
    ENDIF.

    TRY.
        parse_qad_response_xml(
          EXPORTING
            iv_response_xml    = lv_response_xml
          IMPORTING
            et_tracking_info   = et_tracking_info
            et_return_messages = DATA(lt_parsed_errors) ).
        APPEND LINES OF lt_parsed_errors TO et_errors.
      CATCH zcx_qad_simple_error INTO DATA(lx_parse_error).
        APPEND VALUE #( type = 'E' message = lx_parse_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_parse_error.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.