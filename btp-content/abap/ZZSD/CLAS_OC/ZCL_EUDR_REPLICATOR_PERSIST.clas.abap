CLASS zcl_eudr_replicator_persist DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    TYPES:
      BEGIN OF ty_product_ref,
        item_key             TYPE string,
        product_id           TYPE string,
        cn_code              TYPE string,
        eudr_commodity_codes TYPE string_table,
      END OF ty_product_ref,

      BEGIN OF ty_eudr_document,
        osapiens_assessment_key TYPE string,
        readable_id             TYPE string,
        activity_type           TYPE string,
        last_update_date        TYPE string,
        assessment_date         TYPE string,
        product_list            TYPE STANDARD TABLE OF ty_product_ref WITH EMPTY KEY,
      END OF ty_eudr_document,

      BEGIN OF ty_api_response,
        has_more          TYPE abap_bool,
        next_time_from    TYPE string,
        current_time_from TYPE string,
        data              TYPE STANDARD TABLE OF ty_eudr_document WITH EMPTY KEY,
      END OF ty_api_response.

    PROTECTED SECTION.
    PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_EUDR_REPLICATOR_PERSIST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    " ========================================================================
    "              GRAND UNIFIED TESTER (Extended v2)
    " ========================================================================

    " 1. CREDENTIALS
    " User: un.a707cf9d-f4db-47e0-a228-6c05898a9036
    " Pass: UfHkm8yGA7Zaq8G2jSWqqvgSD4m3
    DATA(lv_username) = CONV string( 'un.a707cf9d-f4db-47e0-a228-6c05898a9036' ).
    DATA(lv_password) = CONV string( 'UfHkm8yGA7Zaq8G2jSWqqvgSD4m3' ).

    " The Base64 string you found (user:pass encoded)
    DATA(lv_full_token) = CONV string( 'dW4uYTcwN2NmOWQtZjRkYi00N2UwLWEyMjgtNmMwNTg5OGE5MDM2OlVmSGttOHlHQTdaYXE4RzJqU1dxcXZnU0Q0bTM=' ).

    " 2. TENANT IDs
    DATA(lv_uuid) = 'a707cf9d-f4db-47e0-a228-6c05898a9036'.
    DATA(lv_read) = 'cambridge'.

    " 3. DEFINITIONS
    TYPES: BEGIN OF ty_auth_strat,
             name  TYPE string,
             type  TYPE string, " BASIC, BEARER_RAW, BASIC_TOKEN
           END OF ty_auth_strat.
    DATA lt_auths TYPE STANDARD TABLE OF ty_auth_strat.

    TYPES: BEGIN OF ty_path_strat,
             name TYPE string,
             path TYPE string,
           END OF ty_path_strat.
    DATA lt_paths TYPE STANDARD TABLE OF ty_path_strat.

    TYPES: BEGIN OF ty_header_strat,
             name TYPE string,
             val  TYPE string,
           END OF ty_header_strat.
    DATA lt_headers TYPE STANDARD TABLE OF ty_header_strat.

    " --- AUTH STRATEGIES ---
    " 1. Standard Basic Auth (User + Pass)
    APPEND VALUE #( name = 'Basic (User+Pass)' type = 'BASIC' ) TO lt_auths.

    " 2. Bearer Token (Using the full Base64 string as a Bearer token)
    APPEND VALUE #( name = 'Bearer (Base64 Token)' type = 'BEARER_RAW' ) TO lt_auths.

    " 3. Basic Auth (Token as User, No Password) - Like your colleague implies
    APPEND VALUE #( name = 'Basic (Token as User)' type = 'BASIC_TOKEN' ) TO lt_auths.


    " --- PATH STRATEGIES ---
    " 1. Hub Standard
    APPEND VALUE #( name = 'Path: Hub Standard'        path = '/data/integration/supplier-os-hub/supplier-os-hub/api_v1_buyer_eudr_replicate' ) TO lt_paths.

    " 2. Client (Cambridge)
    APPEND VALUE #( name = 'Path: Client (Cambridge)'  path = |/data/integration/{ lv_read }/supplier-os-client/api_v1_buyer_eudr_replicate| ) TO lt_paths.

    " 3. Client (UUID)
    APPEND VALUE #( name = 'Path: Client (UUID)'       path = |/data/integration/{ lv_uuid }/supplier-os-client/api_v1_buyer_eudr_replicate| ) TO lt_paths.

    " 4. Login Attempt (Cambridge) - Checking your 'signin' theory
    APPEND VALUE #( name = 'Path: Login (Cambridge)'   path = |/data/integration/{ lv_read }/DEFAULT/buyer/signin| ) TO lt_paths.


    " --- HEADER STRATEGIES ---
    APPEND VALUE #( name = 'Head: None'       val = '' ) TO lt_headers.
    APPEND VALUE #( name = 'Head: UUID'       val = lv_uuid ) TO lt_headers.
    APPEND VALUE #( name = 'Head: Cambridge'  val = lv_read ) TO lt_headers.


    out->write( |--- STARTING GRAND UNIFIED DIAGNOSTIC v2 ---| ).

    TRY.
        DATA(lv_base_url) = CONV string( 'https://preprod.osapiens.cloud' ).
        DATA(lo_dest) = cl_http_destination_provider=>create_by_url( lv_base_url ).
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).

        LOOP AT lt_auths INTO DATA(ls_auth).
          LOOP AT lt_paths INTO DATA(ls_path).
             LOOP AT lt_headers INTO DATA(ls_head).

                DATA(lv_test_name) = |{ ls_auth-name }  { ls_path-name } { ls_head-name }|.
                out->write( |Testing: { lv_test_name }| ).

                DATA(lo_req) = lo_client->get_http_request( ).

                " 1. Set Auth
                IF ls_auth-type = 'BASIC'.
                   lo_req->set_authorization_basic( i_username = lv_username i_password = lv_password ).
                ELSEIF ls_auth-type = 'BEARER_RAW'.
                   " Inject the exact string you decoded as a Bearer token
                   lo_req->set_header_field( i_name = 'Authorization' i_value = |Bearer { lv_full_token }| ).
                ELSEIF ls_auth-type = 'BASIC_TOKEN'.
                   " Try using the token as the username (with empty password)
                   lo_req->set_authorization_basic( i_username = lv_full_token i_password = '' ).
                ENDIF.

                " 2. Set Path
                lo_req->set_uri_path( i_uri_path = ls_path-path ).

                " 3. Query (Only for replication paths)
                IF ls_path-name CP '*Login*'.
                   lo_req->set_query( query = '' ). " Login usually is POST, but testing GET for connectivity
                ELSE.
                   lo_req->set_query( query = 'timeFrom=2022-12-20T00:00:00.000Z' ).
                ENDIF.

                " 4. Set Headers
                lo_req->set_header_field( i_name = 'x-osapiens-tenant-id' i_value = '' ).
                IF ls_head-val IS NOT INITIAL.
                   lo_req->set_header_field( i_name = 'x-osapiens-tenant-id' i_value = ls_head-val ).
                ENDIF.
                lo_req->set_header_field( i_name = 'accept' i_value = 'application/json' ).

                " 5. Execute
                DATA(lo_resp) = lo_client->execute( i_method = if_web_http_client=>get ).
                DATA(ls_stat) = lo_resp->get_status( ).

                " 6. Check Result
                IF ls_stat-code = 200.
                   DATA(lv_res) = lo_resp->get_text( ).
                   IF strlen( lv_res ) > 100. lv_res = lv_res(100). ENDIF.
                   out->write( |>>> VICTORY! { lv_test_name } worked! <<<| ).
                   out->write( |   Response: { lv_res }| ).
                   RETURN.
                ELSE.
                   out->write( |   Failed: { ls_stat-code }| ).
                ENDIF.

             ENDLOOP.
          ENDLOOP.
        ENDLOOP.

    CATCH cx_root INTO DATA(lx_root).
        out->write( |Exception: { lx_root->get_text( ) }| ).
    ENDTRY.

    out->write( |--- DIAGNOSTIC COMPLETE ---| ).

  ENDMETHOD.
ENDCLASS.