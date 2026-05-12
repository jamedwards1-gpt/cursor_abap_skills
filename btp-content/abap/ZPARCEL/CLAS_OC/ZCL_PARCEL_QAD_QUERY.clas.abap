CLASS zcl_parcel_qad_query DEFINITION
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
    TYPES:
      BEGIN OF ty_run_message,
        severity TYPE string,
        text     TYPE string,
      END OF ty_run_message.
    TYPES tt_run_messages TYPE STANDARD TABLE OF ty_run_message WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_region_profile,
        trax_client   TYPE string,
        default_start TYPE i,
        ref_width     TYPE i,
      END OF ty_region_profile.
    TYPES ty_response_kind TYPE c LENGTH 10.

    CONSTANTS:
      BEGIN OF gc_poll_status,
        submitted TYPE zparcel_poll_log-status VALUE 'SUBMITTED',
        polling   TYPE zparcel_poll_log-status VALUE 'POLLING',
        complete  TYPE zparcel_poll_log-status VALUE 'COMPLETE',
        error     TYPE zparcel_poll_log-status VALUE 'ERROR',
      END OF gc_poll_status,
      BEGIN OF gc_response_kind,
        final   TYPE ty_response_kind VALUE 'FINAL',
        pending TYPE ty_response_kind VALUE 'PENDING',
        gap     TYPE ty_response_kind VALUE 'GAP',
        error   TYPE ty_response_kind VALUE 'ERROR',
      END OF gc_response_kind.

    METHODS query_shipment_info
      IMPORTING
        iv_use_mock_data TYPE abap_bool DEFAULT abap_false
      EXPORTING
        et_tracking_info TYPE tt_qad_tracking_info
        et_errors        TYPE tt_error_messages
      CHANGING
        cs_shipment_key  TYPE ty_qad_shipment_key
      RAISING
        zcx_parcel_qad_error.

    METHODS check_shipment_status
      IMPORTING
        is_shipment_key  TYPE ty_qad_shipment_key
      EXPORTING
        et_tracking_info TYPE tt_qad_tracking_info
        et_errors        TYPE tt_error_messages
      RAISING
        zcx_parcel_qad_error.

    METHODS poll_pending_queue
      IMPORTING
        iv_trax_client TYPE string DEFAULT 'UK1'
        iv_max_items   TYPE i DEFAULT 10
      EXPORTING
        et_messages TYPE tt_run_messages.

    METHODS discover_shipments
      IMPORTING
        iv_trax_client TYPE string DEFAULT 'UK1'
        iv_max_items   TYPE i DEFAULT 5
      EXPORTING
        et_messages TYPE tt_run_messages.

  PRIVATE SECTION.
    METHODS build_qad_request_xml
      IMPORTING
        is_shipment_key        TYPE ty_qad_shipment_key
      RETURNING
        VALUE(rv_xml_string) TYPE string
      RAISING
        zcx_parcel_qad_error.

    METHODS parse_qad_response_xml
      IMPORTING
        iv_response_xml      TYPE string
      EXPORTING
        et_tracking_info     TYPE tt_qad_tracking_info
        et_return_messages   TYPE tt_error_messages
      RAISING
        zcx_parcel_qad_error.

    METHODS call_qad_api
      IMPORTING
        iv_request_xml       TYPE string
        iv_use_mock_data     TYPE abap_bool
      RETURNING
        VALUE(rv_response_xml) TYPE string
      RAISING
        zcx_parcel_qad_error.

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

    METHODS get_region_profile
      IMPORTING
        iv_trax_client TYPE string
      RETURNING
        VALUE(rs_profile) TYPE ty_region_profile.

    METHODS format_shipment_reference
      IMPORTING
        iv_sequence  TYPE i
        is_profile   TYPE ty_region_profile
      RETURNING
        VALUE(rv_reference) TYPE string.

    METHODS resolve_next_sequence
      IMPORTING
        is_profile TYPE ty_region_profile
      RETURNING
        VALUE(rv_sequence) TYPE i.

    METHODS classify_response
      IMPORTING
        it_errors        TYPE tt_error_messages
        it_tracking_info TYPE tt_qad_tracking_info
      RETURNING
        VALUE(rv_kind) TYPE ty_response_kind.

    METHODS build_trax_tag
      IMPORTING
        iv_trax_client TYPE string
      RETURNING
        VALUE(rv_tag) TYPE string.

    METHODS extract_trax_client
      IMPORTING
        iv_status_message TYPE string
        iv_fallback       TYPE string
      RETURNING
        VALUE(rv_trax_client) TYPE string.

    METHODS current_utclong
      RETURNING
        VALUE(rv_timestamp) TYPE utclong.

    METHODS update_poll_log
      IMPORTING
        iv_log_uuid        TYPE zparcel_poll_log-shipment_uuid
        iv_status          TYPE zparcel_poll_log-status
        iv_status_message  TYPE string
        iv_increment_poll  TYPE i DEFAULT 0.

    METHODS execute_shipment_query
      IMPORTING
        is_shipment_key  TYPE ty_qad_shipment_key
        iv_use_mock_data TYPE abap_bool
      EXPORTING
        et_tracking_info TYPE tt_qad_tracking_info
        et_errors        TYPE tt_error_messages
      RAISING
        zcx_parcel_qad_error.

    METHODS apply_poll_log_outcome
      IMPORTING
        iv_log_uuid      TYPE zparcel_poll_log-shipment_uuid
        iv_response_kind TYPE ty_response_kind
        it_errors        TYPE tt_error_messages
        iv_increment_poll TYPE abap_bool DEFAULT abap_true.

    METHODS append_run_message
      IMPORTING
        iv_severity TYPE string
        iv_text     TYPE string
      CHANGING
        ct_messages TYPE tt_run_messages.

ENDCLASS.



CLASS zcl_parcel_qad_query IMPLEMENTATION.

  METHOD append_run_message.
    APPEND VALUE #(
      severity = iv_severity
      text     = iv_text
    ) TO ct_messages.
  ENDMETHOD.

  METHOD apply_poll_log_outcome.
    DATA lv_message TYPE string.
    DATA lv_status TYPE zparcel_poll_log-status.
    DATA lv_increment TYPE i.

    lv_increment = COND i( WHEN iv_increment_poll = abap_true THEN 1 ELSE 0 ).

    CASE iv_response_kind.
      WHEN gc_response_kind-final.
        lv_status = gc_poll_status-complete.
        lv_message = 'Final shipment response received.'.
      WHEN gc_response_kind-pending.
        lv_status = gc_poll_status-polling.
        lv_message = |Pending QAD response: { COND string( WHEN it_errors IS NOT INITIAL THEN it_errors[ 1 ]-message ELSE 'Awaiting final response' ) }|.
      WHEN gc_response_kind-gap.
        lv_status = gc_poll_status-error.
        lv_message = 'No shipment data returned for this reference.'.
      WHEN OTHERS.
        lv_status = gc_poll_status-error.
        lv_message = COND string(
          WHEN line_exists( it_errors[ type = 'E' ] ) THEN it_errors[ type = 'E' ]-message
          ELSE 'QAD query failed.'
        ).
    ENDCASE.

    update_poll_log(
      iv_log_uuid       = iv_log_uuid
      iv_status         = lv_status
      iv_status_message = lv_message
      iv_increment_poll = lv_increment
    ).
  ENDMETHOD.

  METHOD build_qad_request_xml.
    CONSTANTS:
      BEGIN OF lc_credentials,
        user TYPE string VALUE 'cup-api-test',
        pass TYPE string VALUE 'xeYKheH7oL92UPHt8S4E',
      END OF lc_credentials.

    IF is_shipment_key-shipment_reference IS INITIAL.
      RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'ShipmentReference is missing for GTTE message'.
    ENDIF.

    DATA lv_unique_message_id TYPE string.
    DATA lv_creation_datetime TYPE string.

    lv_unique_message_id = cl_system_uuid=>create_uuid_c22_static( ).

    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    lv_creation_datetime = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }T{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }Z|.

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

  METHOD build_trax_tag.
    rv_tag = |TRAX:{ iv_trax_client }|.
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
            RAISE EXCEPTION TYPE zcx_parcel_qad_error
              EXPORTING previous = lx_dest_prov_root_error
                        message  = |Error creating destination '{ lv_destination_name }' ({ lv_dp_err_class_name }): { lx_dest_prov_root_error->get_text( ) }|.
        ENDTRY.

        IF lo_destination IS NOT BOUND.
          RAISE EXCEPTION TYPE zcx_parcel_qad_error
            EXPORTING message = |Destination '{ lv_destination_name }' could not be created.|.
        ENDIF.

        lo_http_client = cl_web_http_client_manager=>create_by_http_destination( i_destination = lo_destination ).
        IF lo_http_client IS NOT BOUND.
          RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'Failed to create HTTP client from destination.'.
        ENDIF.

        TRY.
            lo_request = lo_http_client->get_http_request( ).
            IF lo_request IS NOT BOUND.
              RAISE EXCEPTION TYPE zcx_parcel_qad_error
                EXPORTING message = 'get_http_request() returned an initial object. Check destination/client validity.'.
            ENDIF.
          CATCH cx_root INTO DATA(lx_get_request_error).
             RAISE EXCEPTION TYPE zcx_parcel_qad_error
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
                                      i_value = 'SPS_SHIP' ).

        lo_request->set_text( i_text = lv_form_data ).

        lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).

        IF lo_response IS NOT BOUND.
          RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'HTTP response object is initial after execute.'.
        ENDIF.

        DATA lo_status_obj    TYPE if_web_http_response=>http_status.
        DATA lv_status_code   TYPE i.
        DATA lv_reason_phrase TYPE string VALUE '(Reason phrase unavailable)'.

        lo_status_obj = lo_response->get_status( ).
        lv_status_code = lo_status_obj-code.

        rv_response_xml = lo_response->get_text( ).

        IF lv_status_code <> 200.
          IF lo_http_client IS BOUND. lo_http_client->close( ). ENDIF.
          RAISE EXCEPTION TYPE zcx_parcel_qad_error
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
        RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING previous = lx_http_client_error message = |HTTP Client Error: { lx_http_client_error->get_text( ) }|.
      CATCH cx_root INTO DATA(lx_root_error).
        IF lo_http_client IS BOUND.
            TRY.
                lo_http_client->close( ).
              CATCH cx_web_http_client_error.
            ENDTRY.
        ENDIF.
        DATA(lv_err_class_name) = cl_abap_classdescr=>get_class_name( lx_root_error ).
        RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING previous = lx_root_error message = |Unexpected Error ({ lv_err_class_name }): { lx_root_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD check_shipment_status.
    CLEAR: et_tracking_info, et_errors.

    execute_shipment_query(
      EXPORTING
        is_shipment_key  = is_shipment_key
        iv_use_mock_data = abap_false
      IMPORTING
        et_tracking_info = et_tracking_info
        et_errors        = et_errors
    ).

    IF is_shipment_key-log_uuid IS NOT INITIAL.
      apply_poll_log_outcome(
        iv_log_uuid      = is_shipment_key-log_uuid
        iv_response_kind = classify_response(
          it_errors        = et_errors
          it_tracking_info = et_tracking_info
        )
        it_errors        = et_errors
      ).
    ENDIF.
  ENDMETHOD.

  METHOD classify_response.
    IF line_exists( it_errors[ type = 'E' ] ).
      rv_kind = gc_response_kind-error.
      RETURN.
    ENDIF.

    IF line_exists( it_errors[ type = 'W' ] ).
      rv_kind = gc_response_kind-pending.
      RETURN.
    ENDIF.

    IF it_tracking_info IS NOT INITIAL.
      rv_kind = gc_response_kind-final.
      RETURN.
    ENDIF.

    rv_kind = gc_response_kind-gap.
  ENDMETHOD.

  METHOD current_utclong.
    CALL METHOD cl_abap_utclong=>from_system_timestamp
      EXPORTING
        system_date = cl_abap_context_info=>get_system_date( )
        system_time = cl_abap_context_info=>get_system_time( )
      IMPORTING
        utc_tstmp = rv_timestamp.
  ENDMETHOD.

  METHOD discover_shipments.
    DATA ls_profile TYPE ty_region_profile.
    DATA lv_sequence TYPE i.
    DATA ls_ship_key TYPE ty_qad_shipment_key.
    DATA lt_tracking TYPE tt_qad_tracking_info.
    DATA lt_errors TYPE tt_error_messages.
    DATA lv_kind TYPE ty_response_kind.
    DATA lv_gap_found TYPE abap_bool.

    CLEAR et_messages.
    ls_profile = get_region_profile( iv_trax_client ).
    lv_sequence = resolve_next_sequence( ls_profile ).

    append_run_message(
      EXPORTING
        iv_severity = 'S'
        iv_text     = |Discovering shipments for { ls_profile-trax_client } from sequence { lv_sequence }|
      CHANGING
        ct_messages = et_messages
    ).

    DO iv_max_items TIMES.
      CLEAR: lt_tracking, lt_errors, ls_ship_key.
      lv_sequence = lv_sequence + 1.

      ls_ship_key-trax_client = ls_profile-trax_client.
      ls_ship_key-shipment_reference = format_shipment_reference(
        iv_sequence = lv_sequence
        is_profile  = ls_profile
      ).

      append_run_message(
        EXPORTING
          iv_severity = 'S'
          iv_text     = |Querying { ls_ship_key-shipment_reference } for { ls_profile-trax_client }|
        CHANGING
          ct_messages = et_messages
      ).

      TRY.
          query_shipment_info(
            EXPORTING
              iv_use_mock_data = abap_false
            IMPORTING
              et_tracking_info = lt_tracking
              et_errors        = lt_errors
            CHANGING
              cs_shipment_key  = ls_ship_key
          ).
        CATCH zcx_parcel_qad_error INTO DATA(lx_qad_error).
          append_run_message(
            EXPORTING
              iv_severity = 'E'
              iv_text     = |Query failed for { ls_ship_key-shipment_reference }: { lx_qad_error->get_text( ) }|
            CHANGING
              ct_messages = et_messages
          ).
          CONTINUE.
      ENDTRY.

      lv_kind = classify_response(
        it_errors        = lt_errors
        it_tracking_info = lt_tracking
      ).

      CASE lv_kind.
        WHEN gc_response_kind-gap.
          append_run_message(
            EXPORTING
              iv_severity = 'W'
              iv_text     = |Gap found at { ls_ship_key-shipment_reference }. Stopping discovery.|
            CHANGING
              ct_messages = et_messages
          ).
          lv_gap_found = abap_true.
          EXIT.
        WHEN gc_response_kind-pending.
          append_run_message(
            EXPORTING
              iv_severity = 'S'
              iv_text     = |Pending response for { ls_ship_key-shipment_reference }; queued for follow-up polling.|
            CHANGING
              ct_messages = et_messages
          ).
        WHEN gc_response_kind-final.
          append_run_message(
            EXPORTING
              iv_severity = 'S'
              iv_text     = |Final response received for { ls_ship_key-shipment_reference }|
            CHANGING
              ct_messages = et_messages
          ).
        WHEN OTHERS.
          append_run_message(
            EXPORTING
              iv_severity = 'E'
              iv_text     = |Error response for { ls_ship_key-shipment_reference }|
            CHANGING
              ct_messages = et_messages
          ).
      ENDCASE.
    ENDDO.

    IF lv_gap_found = abap_false.
      append_run_message(
        EXPORTING
          iv_severity = 'S'
          iv_text     = 'Discovery batch complete.'
        CHANGING
          ct_messages = et_messages
      ).
    ENDIF.
  ENDMETHOD.

  METHOD escape_for_xml.
    rv_escaped_string = iv_unescaped_string.
    REPLACE ALL OCCURRENCES OF '&' IN rv_escaped_string WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '<' IN rv_escaped_string WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN rv_escaped_string WITH '&gt;'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_escaped_string WITH '&quot;'.
    REPLACE ALL OCCURRENCES OF '''' IN rv_escaped_string WITH '&apos;'.
  ENDMETHOD.

  METHOD execute_shipment_query.
    DATA lv_request_xml TYPE string.
    DATA lv_response_xml TYPE string.

    CLEAR: et_tracking_info, et_errors.

    TRY.
        lv_request_xml = build_qad_request_xml( is_shipment_key ).
      CATCH zcx_parcel_qad_error INTO DATA(lx_build_error).
        APPEND VALUE #( type = 'E' message = lx_build_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_build_error.
    ENDTRY.

    TRY.
        lv_response_xml = call_qad_api(
          iv_request_xml   = lv_request_xml
          iv_use_mock_data = iv_use_mock_data
        ).
      CATCH zcx_parcel_qad_error INTO DATA(lx_call_error).
        APPEND VALUE #( type = 'E' message = lx_call_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_call_error.
    ENDTRY.

    IF iv_use_mock_data = abap_false AND lv_response_xml IS INITIAL.
      RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'QAD API call returned an empty response.'.
    ENDIF.

    TRY.
        parse_qad_response_xml(
          EXPORTING
            iv_response_xml    = lv_response_xml
          IMPORTING
            et_tracking_info   = et_tracking_info
            et_return_messages = DATA(lt_parsed_errors)
        ).
        APPEND LINES OF lt_parsed_errors TO et_errors.
      CATCH zcx_parcel_qad_error INTO DATA(lx_parse_error).
        APPEND VALUE #( type = 'E' message = lx_parse_error->get_text( ) ) TO et_errors.
        RAISE EXCEPTION lx_parse_error.
    ENDTRY.
  ENDMETHOD.

  METHOD extract_trax_client.
    rv_trax_client = iv_fallback.
    IF iv_status_message CP 'TRAX:*'.
      DATA(lv_stripped) = iv_status_message+5.
      rv_trax_client = lv_stripped(3).
    ENDIF.
  ENDMETHOD.

  METHOD format_shipment_reference.
    DATA lv_numeric TYPE n LENGTH 10.
    lv_numeric = iv_sequence.
    rv_reference = lv_numeric.
    SHIFT rv_reference LEFT DELETING LEADING '0'.
    WHILE strlen( rv_reference ) < is_profile-ref_width.
      rv_reference = |0{ rv_reference }|.
    ENDWHILE.
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
     &&       `<Tracking></Tracking>`
     &&       `<Errors>`
     &&         `<Error>`
     &&           `<ErrorNumber>QAD001</ErrorNumber>`
     &&           `<ErrorText>Mocked QAD Processing Error Text</ErrorText>`
     &&           `<ErrorPageURL>http://qad.com/error/QAD001</ErrorPageURL>`
     &&           `<ErrorTable>XMSHDR0</ErrorTable>`
     &&           `<ErrorTableKey>KEY123</ErrorTableKey>`
     &&           `<Action><Sequence>10</Sequence><Type>VALIDATE</Type><Severity>ERROR</Severity></Action>`
     &&         `</Error>`
     &&       `</Errors>`
     &&     `</SPSResponse>`
     &&   `</DataArea>`
     && `</ProcessSPSResponse>`.
  ENDMETHOD.

  METHOD get_mock_qad_response.
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

  METHOD get_region_profile.
    CASE iv_trax_client.
      WHEN 'UK1'.
        rs_profile = VALUE #(
          trax_client   = 'UK1'
          default_start = 1176
          ref_width     = 7
        ).
      WHEN 'AU1'.
        rs_profile = VALUE #(
          trax_client   = 'AU1'
          default_start = 1179
          ref_width     = 7
        ).
      WHEN OTHERS.
        rs_profile = VALUE #(
          trax_client   = iv_trax_client
          default_start = 1176
          ref_width     = 7
        ).
    ENDCASE.
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
      RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'Received empty XML response for parsing.'.
    ENDIF.

    TRY.
        lv_response_xstring = cl_abap_conv_codepage=>create_out( codepage = 'UTF-8' )->convert( iv_response_xml ).

        lo_ixml_core      = cl_ixml_core=>create( ).
        lo_stream_factory = lo_ixml_core->create_stream_factory( ).
        lo_document       = lo_ixml_core->create_document( ).
        lo_istream        = lo_stream_factory->create_istream_xstring( string = lv_response_xstring ).
        lo_parser         = lo_ixml_core->create_parser( stream_factory = lo_stream_factory istream = lo_istream document = lo_document ).

        IF lo_parser->parse( ) <> 0.
          RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'XML Parser returned a non-zero code'.
        ENDIF.

        DATA(lo_root_element) = lo_document->get_root_element( ).
        IF lo_root_element IS NOT BOUND.
          RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'Could not find root element in response.'.
        ENDIF.

        DATA(lv_root_name) = lo_root_element->get_name( ).

        CASE lv_root_name.
          WHEN 'Highway'.
            DATA(lv_comment) = get_element_value( io_parent_element = lo_root_element iv_name = 'Comment' ).
            DATA(lv_status)  = get_element_value( io_parent_element = lo_root_element iv_name = 'com.precisionsoftware.highway.ui.web.HttpsAuthReader' ).
            APPEND VALUE #( type = 'W' message = |Highway Status: { lv_status } Comment: { lv_comment }| ) TO et_return_messages.

          WHEN 'ProcessSPSResponse'.
            DATA(lo_data_area) = lo_root_element->find_from_name_ns( name = 'DataArea' ).
            IF lo_data_area IS NOT BOUND.
              RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'DataArea element not found in ProcessSPSResponse.'.
            ENDIF.

            DATA(lo_sps_response_data) = lo_data_area->find_from_name_ns( name = 'SPSResponse' ).
            IF lo_sps_response_data IS NOT BOUND.
              RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING message = 'SPSResponse element not found in DataArea.'.
            ENDIF.

            DATA(lo_errors_node) = lo_sps_response_data->find_from_name_ns( name = 'Errors' ).
            IF lo_errors_node IS BOUND.
              DATA(lo_error_list) = lo_errors_node->get_elements_by_tag_name_ns( name = 'Error' uri = `` ).
              DATA lo_current_error_node TYPE REF TO if_ixml_node.
              DO lo_error_list->get_length( ) TIMES.
                lo_current_error_node = lo_error_list->get_item( sy-index - 1 ).
                IF lo_current_error_node IS BOUND AND lo_current_error_node->get_type( ) = if_ixml_node=>co_node_element.
                  DATA(lo_error_element) = CAST if_ixml_element( lo_current_error_node ).
                  APPEND VALUE #(
                    type    = 'E'
                    message = get_element_value( io_parent_element = lo_error_element iv_name = 'ErrorText' )
                  ) TO et_return_messages.
                ENDIF.
              ENDDO.
            ENDIF.

            DATA(lo_tracking_node) = lo_sps_response_data->find_from_name_ns( name = 'Tracking' ).
            IF lo_tracking_node IS BOUND AND NOT line_exists( et_return_messages[ type = 'E' ] ).
              DATA ls_trc_h TYPE zpar_trc_h.
              ls_trc_h-client = sy-mandt.
              ls_trc_h-qad_shipment_ref    = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'ShipmentReference' ).
              ls_trc_h-shipper_id          = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'Shipper' ).
              ls_trc_h-trax_client         = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'TRAXClient' ).
              ls_trc_h-service_code        = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'Service' ).
              ls_trc_h-global_carrier_code = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'GlobalCarrierCode' ).

              DATA(lv_despatch_date_str) = get_element_value( io_parent_element = lo_sps_response_data iv_name = 'DespatchDate' ).
              IF strlen( lv_despatch_date_str ) >= 10.
                REPLACE ALL OCCURRENCES OF '-' IN lv_despatch_date_str WITH ''.
                ls_trc_h-despatch_date = lv_despatch_date_str(8).
              ENDIF.

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

              DATA(lo_charge_total_node) = lo_sps_response_data->find_from_name_ns( name = 'ChargeTotal' ).
              IF lo_charge_total_node IS BOUND.
                DATA(lo_sell_amount_node) = lo_charge_total_node->find_from_name_ns( name = 'SellAmount' ).
                IF lo_sell_amount_node IS BOUND.
                  ls_trc_h-total_charge_sell = get_element_value( io_parent_element = lo_sell_amount_node iv_name = 'Value' ).
                  ls_trc_h-currency_code     = get_element_value( io_parent_element = lo_sell_amount_node iv_name = 'Currency' ).
                ENDIF.
              ENDIF.

              IF ls_trc_h-erp_delivery_number IS NOT INITIAL AND ls_trc_h-qad_shipment_ref IS NOT INITIAL.
                MODIFY zpar_trc_h FROM @ls_trc_h.
              ENDIF.

              DATA lt_trc_p TYPE STANDARD TABLE OF zpar_trc_p.
              DATA(lo_tracking_details_nodelist) = lo_tracking_node->get_elements_by_tag_name_ns( name = 'TrackingDetails' uri = `` ).
              DATA lo_current_td_node TYPE REF TO if_ixml_node.

              DO lo_tracking_details_nodelist->get_length( ) TIMES.
                lo_current_td_node = lo_tracking_details_nodelist->get_item( sy-index - 1 ).
                IF lo_current_td_node IS BOUND AND lo_current_td_node->get_type( ) = if_ixml_node=>co_node_element.
                  DATA(lo_td_element) = CAST if_ixml_element( lo_current_td_node ).

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

              IF lt_trc_p IS NOT INITIAL.
                DELETE FROM zpar_trc_p WHERE erp_delivery_number = @ls_trc_h-erp_delivery_number
                                          AND qad_shipment_ref = @ls_trc_h-qad_shipment_ref.
                INSERT zpar_trc_p FROM TABLE @lt_trc_p.
              ENDIF.
            ENDIF.

          WHEN OTHERS.
            RAISE EXCEPTION TYPE zcx_parcel_qad_error
              EXPORTING message = |Unexpected XML root element received: '{ lv_root_name }'|.
        ENDCASE.

    CATCH cx_root INTO DATA(lx_ixml_error).
      RAISE EXCEPTION TYPE zcx_parcel_qad_error EXPORTING previous = lx_ixml_error.
    ENDTRY.
  ENDMETHOD.

  METHOD poll_pending_queue.
    DATA lt_queue TYPE STANDARD TABLE OF zparcel_poll_log.
    DATA ls_ship_key TYPE ty_qad_shipment_key.
    DATA lt_tracking TYPE tt_qad_tracking_info.
    DATA lt_errors TYPE tt_error_messages.
    DATA lv_kind TYPE ty_response_kind.
    DATA lv_trax_client TYPE string.

    CLEAR et_messages.

    SELECT *
      FROM zparcel_poll_log
      WHERE status = @gc_poll_status-submitted
         OR status = @gc_poll_status-polling
      ORDER BY created_at ASCENDING
      INTO TABLE @lt_queue
      UP TO @iv_max_items ROWS.

    IF lt_queue IS INITIAL.
      append_run_message(
        EXPORTING
          iv_severity = 'S'
          iv_text     = 'No pending shipment logs found.'
        CHANGING
          ct_messages = et_messages
      ).
      RETURN.
    ENDIF.

    append_run_message(
      EXPORTING
        iv_severity = 'S'
        iv_text     = |Processing { lines( lt_queue ) } pending shipment log(s).|
      CHANGING
        ct_messages = et_messages
    ).

    LOOP AT lt_queue ASSIGNING FIELD-SYMBOL(<fs_log_entry>).
      CLEAR: ls_ship_key, lt_tracking, lt_errors.

      lv_trax_client = extract_trax_client(
        iv_status_message = <fs_log_entry>-status_message
        iv_fallback       = iv_trax_client
      ).

      IF <fs_log_entry>-status_message CP 'TRAX:*'
         AND lv_trax_client <> iv_trax_client.
        CONTINUE.
      ENDIF.

      ls_ship_key-shipment_reference = <fs_log_entry>-shipment_reference.
      ls_ship_key-trax_client        = lv_trax_client.
      ls_ship_key-log_uuid           = <fs_log_entry>-shipment_uuid.

      append_run_message(
        EXPORTING
          iv_severity = 'S'
          iv_text     = |Checking { ls_ship_key-shipment_reference } for { lv_trax_client }|
        CHANGING
          ct_messages = et_messages
      ).

      TRY.
          check_shipment_status(
            EXPORTING
              is_shipment_key = ls_ship_key
            IMPORTING
              et_tracking_info = lt_tracking
              et_errors        = lt_errors
          ).
        CATCH zcx_parcel_qad_error INTO DATA(lx_qad_error).
          update_poll_log(
            iv_log_uuid       = ls_ship_key-log_uuid
            iv_status         = gc_poll_status-error
            iv_status_message = lx_qad_error->get_text( )
            iv_increment_poll = 1
          ).
          append_run_message(
            EXPORTING
              iv_severity = 'E'
              iv_text     = |Status check failed for { ls_ship_key-shipment_reference }: { lx_qad_error->get_text( ) }|
            CHANGING
              ct_messages = et_messages
          ).
          CONTINUE.
      ENDTRY.

      lv_kind = classify_response(
        it_errors        = lt_errors
        it_tracking_info = lt_tracking
      ).

      append_run_message(
        EXPORTING
          iv_severity = COND string( WHEN lv_kind = gc_response_kind-error THEN 'E' WHEN lv_kind = gc_response_kind-gap THEN 'W' ELSE 'S' )
          iv_text     = |{ ls_ship_key-shipment_reference } classified as { lv_kind }|
        CHANGING
          ct_messages = et_messages
      ).
    ENDLOOP.
  ENDMETHOD.

  METHOD query_shipment_info.
    DATA ls_local_ship_key LIKE cs_shipment_key.
    DATA lv_kind TYPE ty_response_kind.

    ls_local_ship_key = cs_shipment_key.
    ls_local_ship_key-log_uuid = cl_system_uuid=>create_uuid_x16_static( ).
    cs_shipment_key-log_uuid   = ls_local_ship_key-log_uuid.

    CLEAR: et_tracking_info, et_errors.

    DATA(ls_log_entry) = VALUE zparcel_poll_log(
      client                = sy-mandt
      shipment_uuid         = ls_local_ship_key-log_uuid
      shipment_reference    = ls_local_ship_key-shipment_reference
      status                = gc_poll_status-submitted
      status_message        = build_trax_tag( ls_local_ship_key-trax_client )
      poll_count            = 0
      created_at            = current_utclong( )
      last_changed_at       = current_utclong( )
      local_last_changed_at = current_utclong( )
    ).
    INSERT zparcel_poll_log FROM @ls_log_entry.

    TRY.
        execute_shipment_query(
          EXPORTING
            is_shipment_key  = ls_local_ship_key
            iv_use_mock_data = iv_use_mock_data
          IMPORTING
            et_tracking_info = et_tracking_info
            et_errors        = et_errors
        ).
      CATCH zcx_parcel_qad_error INTO DATA(lx_query_error).
        apply_poll_log_outcome(
          iv_log_uuid      = ls_local_ship_key-log_uuid
          iv_response_kind = gc_response_kind-error
          it_errors        = et_errors
          iv_increment_poll = abap_false
        ).
        RAISE EXCEPTION lx_query_error.
    ENDTRY.

    lv_kind = classify_response(
      it_errors        = et_errors
      it_tracking_info = et_tracking_info
    ).

    apply_poll_log_outcome(
      iv_log_uuid      = ls_local_ship_key-log_uuid
      iv_response_kind = lv_kind
      it_errors        = et_errors
    ).
  ENDMETHOD.

  METHOD resolve_next_sequence.
    DATA lv_max_h TYPE i.
    DATA lv_max_poll TYPE i.
    DATA lv_max_ref TYPE zpar_trc_h-qad_shipment_ref.
    DATA lv_poll_ref TYPE zparcel_poll_log-shipment_reference.
    DATA lv_trax_pattern TYPE string.

    lv_trax_pattern = |{ build_trax_tag( is_profile-trax_client ) }%|.

    SELECT MAX( qad_shipment_ref )
      FROM zpar_trc_h
      WHERE trax_client = @is_profile-trax_client
      INTO @lv_max_ref.

    IF sy-subrc = 0 AND lv_max_ref IS NOT INITIAL.
      TRY.
          lv_max_h = CONV i( lv_max_ref ).
        CATCH cx_sy_conversion_error.
          CLEAR lv_max_h.
      ENDTRY.
    ENDIF.

    SELECT MAX( shipment_reference )
      FROM zparcel_poll_log
      WHERE shipment_reference IS NOT INITIAL
        AND status_message LIKE @lv_trax_pattern
      INTO @lv_poll_ref.

    IF sy-subrc = 0 AND lv_poll_ref IS NOT INITIAL.
      TRY.
          lv_max_poll = CONV i( lv_poll_ref ).
        CATCH cx_sy_conversion_error.
          CLEAR lv_max_poll.
      ENDTRY.
    ENDIF.

    rv_sequence = lv_max_h.
    IF lv_max_poll > rv_sequence.
      rv_sequence = lv_max_poll.
    ENDIF.

    IF rv_sequence IS INITIAL.
      rv_sequence = is_profile-default_start - 1.
    ENDIF.
  ENDMETHOD.

  METHOD update_poll_log.
    DATA lv_timestamp TYPE utclong.
    DATA lv_existing_message TYPE string.
    DATA lv_status_message TYPE string.
    DATA lv_trax_client TYPE string.

    lv_timestamp = current_utclong( ).

    SELECT SINGLE status_message
      FROM zparcel_poll_log
      WHERE shipment_uuid = @iv_log_uuid
      INTO @lv_existing_message.

    lv_trax_client = extract_trax_client(
      iv_status_message = lv_existing_message
      iv_fallback       = ''
    ).

  IF lv_trax_client IS NOT INITIAL.
    lv_status_message = |{ build_trax_tag( lv_trax_client ) } { iv_status_message }|.
  ELSE.
    lv_status_message = iv_status_message.
  ENDIF.

    UPDATE zparcel_poll_log
      SET status                = @iv_status,
          status_message        = @lv_status_message,
          poll_count            = poll_count + @iv_increment_poll,
          last_changed_at       = @lv_timestamp,
          local_last_changed_at = @lv_timestamp
      WHERE shipment_uuid = @iv_log_uuid.
  ENDMETHOD.

ENDCLASS.
