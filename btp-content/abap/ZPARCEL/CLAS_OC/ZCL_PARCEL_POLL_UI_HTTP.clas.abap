CLASS zcl_parcel_poll_ui_http DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_parcel_poll_ui_http IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.

    DATA lv_method TYPE string.
    DATA lv_body TYPE string.
    DATA lv_json TYPE string.
    DATA lv_op TYPE string.
    DATA lv_client TYPE string.
    DATA lv_batch TYPE i.
    DATA lv_batch_str TYPE string.
    DATA lt_rows TYPE STANDARD TABLE OF zparcel_poll_log WITH DEFAULT KEY.
    DATA lo_qad TYPE REF TO zcl_parcel_qad_query.
    DATA lt_msg TYPE zcl_parcel_qad_query=>tt_run_messages.
    DATA lx TYPE REF TO cx_root.

    TYPES: BEGIN OF ty_cmd,
             op     TYPE string,
             client TYPE string,
             batch  TYPE i,
           END OF ty_cmd.
    DATA ls_cmd TYPE ty_cmd.

    TYPES: BEGIN OF ty_js_row,
             client               TYPE string,
             shipment_reference   TYPE string,
             status               TYPE string,
             status_message       TYPE string,
             poll_count           TYPE string,
             created_at           TYPE string,
             last_changed_at      TYPE string,
           END OF ty_js_row.
    DATA lt_js TYPE STANDARD TABLE OF ty_js_row WITH EMPTY KEY.

    lv_method = request->get_method( ).

    IF lv_method = 'GET'.
      response->set_status( i_code = if_web_http_status=>ok ).
      response->set_header_field(
        i_name  = if_web_http_header=>content_type
        i_value = 'text/html; charset=utf-8' ).

      DATA(lt_html) = VALUE string_table(
        ( `<!DOCTYPE html>` )
        ( `<html lang="en"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>` )
        ( `<title>Parcel QAD poll log</title>` )
        ( `<style>` )
        ( `:root{--bg:#0f172a;--card:#111827;--txt:#e5e7eb;--muted:#94a3b8;--acc:#0a84ff;--bd:#1f2937;}` )
        ( `body{margin:0;font:14px/1.45 system-ui,sans-serif;background:var(--bg);color:var(--txt);}` )
        ( `header{padding:1.25rem 1.5rem;border-bottom:1px solid var(--bd);background:#0b1220;}` )
        ( `h1{margin:0;font-size:1.25rem;font-weight:600;}` )
        ( `p{margin:.35rem 0 0;color:var(--muted);}` )
        ( `main{max-width:1200px;margin:0 auto;padding:1rem 1.25rem 2rem;}` )
        ( `.row{display:flex;flex-wrap:wrap;gap:.5rem;margin:.75rem 0;align-items:center;}` )
        ( `label{color:var(--muted);font-size:.85rem;}` )
        ( `input,select{background:#0b1220;border:1px solid var(--bd);color:var(--txt);border-radius:6px;padding:.45rem .6rem;}` )
        ( `button{background:var(--acc);color:#fff;border:none;border-radius:8px;padding:.55rem 1rem;font-weight:600;cursor:pointer;}` )
        ( `button.secondary{background:#1f2937;color:var(--txt);}` )
        ( `table{width:100%;border-collapse:collapse;margin-top:.75rem;background:var(--card);border-radius:10px;overflow:hidden;border:1px solid var(--bd);}` )
        ( `th,td{padding:.55rem .65rem;text-align:left;border-bottom:1px solid var(--bd);vertical-align:top;}` )
        ( `th{color:var(--muted);font-weight:600;font-size:.8rem;text-transform:uppercase;letter-spacing:.02em;}` )
        ( `tr:last-child td{border-bottom:none;}` )
        ( `#log{background:#0b1220;border:1px solid var(--bd);border-radius:8px;padding:.75rem;min-height:4rem;white-space:pre-wrap;font-family:ui-monospace,Menlo,monospace;font-size:.8rem;color:#cbd5e1;}` )
        ( `</style></head><body>` )
        ( `<header><h1>Parcel QAD — poll log</h1><p>Fiori-style UI from HTTP handler ZCL_PARCEL_POLL_UI_HTTP. In ADT: add an HTTP service` )
        ( ` (communication scenario) that references this class, publish, then open the service URL.</p></header><main>` )
        ( `<div class="row"><label>Trax client</label><select id="c"><option>UK1</option><option>AU1</option></select>` )
        ( `<label>Batch</label><input id="b" type="number" value="5" min="1" max="200"/></div>` )
        ( `<div class="row"><button type="button" id="r">Refresh table</button>` )
        ( `<button type="button" id="p" class="secondary">Run poll queue</button>` )
        ( `<button type="button" id="d" class="secondary">Run discover</button></div>` )
        ( `<div id="log"></div><table><thead><tr><th>Client</th><th>Ref</th><th>Status</th><th>Message</th><th>Count</th><th>Created</th><th>Changed</th></tr></thead><tbody id="t"></tbody></table>` )
        ( `<script>(function(){` )
        ( `function el(id){return document.getElementById(id);}` )
        ( `function log(m){el("log").textContent=m;}` )
        ( `function url(){return window.location.href.split("#")[0];}` )
        ( `async function api(op){` )
        ( `const body=JSON.stringify({op:op,client:el("c").value,batch:parseInt(el("b").value||"5",10)||5});` )
        ( `const r=await fetch(url(),{method:"POST",headers:{"Content-Type":"application/json"},body:body});` )
        ( `const t=await r.text();let j;try{j=JSON.parse(t);}catch(e){throw new Error(t);}if(!r.ok||j.error){throw new Error(j.error||t);}return j;}` )
        ( `function render(rows){` )
        ( `const tb=el("t");tb.innerHTML="";` )
        ( `(rows||[]).forEach(function(row){` )
        ( `const tr=document.createElement("tr");` )
        ( `["client","shipment_reference","status","status_message","poll_count","created_at","last_changed_at"].forEach(function(k){` )
        ( `const td=document.createElement("td");td.textContent=row[k]||"";tr.appendChild(td);});` )
        ( `tb.appendChild(tr);});}` )
        ( `async function refresh(){log("Loading…");try{const j=await api("list");render(j.rows);log("");}catch(e){log(e.message||String(e));}}` )
        ( `async function runPoll(){log("Polling…");try{const j=await api("poll");log(JSON.stringify(j.messages,null,2));await refresh();}catch(e){log(e.message||String(e));}}` )
        ( `async function runDiscover(){log("Discover…");try{const j=await api("discover");log(JSON.stringify(j.messages,null,2));await refresh();}catch(e){log(e.message||String(e));}}` )
        ( `el("r").addEventListener("click",refresh);` )
        ( `el("p").addEventListener("click",runPoll);` )
        ( `el("d").addEventListener("click",runDiscover);` )
        ( `refresh();})();</script></main></body></html>` )
      ).

      response->set_text( i_text = concat_lines_of( table = lt_html sep = cl_abap_char_utilities=>newline ) ).
      RETURN.
    ENDIF.

    IF lv_method <> 'POST'.
      response->set_status( i_code = if_web_http_status=>method_not_allowed ).
      response->set_header_field(
        i_name  = if_web_http_header=>content_type
        i_value = 'application/json' ).
      response->set_text( i_text = `{"error":"Use GET for UI or POST with JSON body."}` ).
      RETURN.
    ENDIF.

    lv_body = request->get_text( ).
    IF lv_body IS INITIAL.
      response->set_status( i_code = if_web_http_status=>bad_request ).
      response->set_header_field(
        i_name  = if_web_http_header=>content_type
        i_value = 'application/json' ).
      response->set_text( i_text = `{"error":"Empty body"}` ).
      RETURN.
    ENDIF.

    CLEAR ls_cmd.
    ls_cmd-batch = 5.
    ls_cmd-client = 'UK1'.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_body
          pretty_name = /ui2/cl_json=>pretty_mode-low_case
          CHANGING data = ls_cmd ).
      CATCH cx_root INTO lx.
        CLEAR ls_cmd.
        ls_cmd-batch = 5.
        ls_cmd-client = 'UK1'.
        IF lv_body CS `"op"`.
          FIND REGEX '"op"\s*:\s*"([^"]*)"' IN lv_body SUBMATCHES ls_cmd-op.
        ENDIF.
        IF lv_body CS `"client"`.
          FIND REGEX '"client"\s*:\s*"([^"]*)"' IN lv_body SUBMATCHES ls_cmd-client.
        ENDIF.
        IF lv_body CS `"batch"`.
          FIND REGEX '"batch"\s*:\s*(\d+)' IN lv_body SUBMATCHES lv_batch_str.
          ls_cmd-batch = CONV i( lv_batch_str ).
        ENDIF.
        IF ls_cmd-op IS INITIAL.
          response->set_status( i_code = if_web_http_status=>bad_request ).
          response->set_header_field(
            i_name  = if_web_http_header=>content_type
            i_value = 'application/json' ).
          response->set_text( i_text = |\{ "error": "{ replace( val = lx->get_text( ) sub = `"` with = `'` occ = 0 ) }" \}| ).
          RETURN.
        ENDIF.
    ENDTRY.

    IF ls_cmd-op IS INITIAL.
      response->set_status( i_code = if_web_http_status=>bad_request ).
      response->set_header_field(
        i_name  = if_web_http_header=>content_type
        i_value = 'application/json' ).
      response->set_text( i_text = `{"error":"Missing op (list, poll, discover)."}` ).
      RETURN.
    ENDIF.

    lv_op = ls_cmd-op.
    lv_client = ls_cmd-client.
    lv_batch = ls_cmd-batch.
    IF lv_batch <= 0.
      lv_batch = 5.
    ENDIF.

    response->set_header_field(
      i_name  = if_web_http_header=>content_type
      i_value = 'application/json' ).

    CASE lv_op.
      WHEN 'list'.
        SELECT FROM zparcel_poll_log
          FIELDS client,
                 shipment_reference,
                 status,
                 status_message,
                 poll_count,
                 created_at,
                 last_changed_at
          ORDER BY last_changed_at DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_rows
          UP TO 200 ROWS.

        CLEAR lt_js.
        LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<r>).
          APPEND VALUE #(
            client             = CONV string( <r>-client )
            shipment_reference = <r>-shipment_reference
            status               = <r>-status
            status_message       = <r>-status_message
            poll_count           = CONV string( <r>-poll_count )
            created_at           = CONV string( <r>-created_at )
            last_changed_at      = CONV string( <r>-last_changed_at )
          ) TO lt_js.
        ENDLOOP.

        lv_json = /ui2/cl_json=>serialize(
          data        = lt_js
          compress    = abap_false
          pretty_name = /ui2/cl_json=>pretty_mode-low_case ).
        response->set_status( i_code = if_web_http_status=>ok ).
        response->set_text( i_text = |\{ "rows": { lv_json } \}| ).

      WHEN 'poll'.
        CREATE OBJECT lo_qad.
        TRY.
            lo_qad->poll_pending_queue(
              EXPORTING
                iv_trax_client = lv_client
                iv_max_items   = lv_batch
              IMPORTING
                et_messages    = lt_msg ).
            lv_json = /ui2/cl_json=>serialize(
              data        = lt_msg
              compress    = abap_false
              pretty_name = /ui2/cl_json=>pretty_mode-low_case ).
            response->set_status( i_code = if_web_http_status=>ok ).
            response->set_text( i_text = |\{ "messages": { lv_json } \}| ).
          CATCH cx_root INTO lx.
            response->set_status( i_code = if_web_http_status=>internal_server_error ).
            response->set_text( i_text = |\{ "error": "{ replace( val = lx->get_text( ) sub = `"` with = `'` occ = 0 ) }" \}| ).
        ENDTRY.

      WHEN 'discover'.
        CREATE OBJECT lo_qad.
        TRY.
            lo_qad->discover_shipments(
              EXPORTING
                iv_trax_client = lv_client
                iv_max_items   = lv_batch
              IMPORTING
                et_messages    = lt_msg ).
            lv_json = /ui2/cl_json=>serialize(
              data        = lt_msg
              compress    = abap_false
              pretty_name = /ui2/cl_json=>pretty_mode-low_case ).
            response->set_status( i_code = if_web_http_status=>ok ).
            response->set_text( i_text = |\{ "messages": { lv_json } \}| ).
          CATCH cx_root INTO lx.
            response->set_status( i_code = if_web_http_status=>internal_server_error ).
            response->set_text( i_text = |\{ "error": "{ replace( val = lx->get_text( ) sub = `"` with = `'` occ = 0 ) }" \}| ).
        ENDTRY.

      WHEN OTHERS.
        response->set_status( i_code = if_web_http_status=>bad_request ).
        response->set_text( i_text = `{"error":"Unknown op; use list, poll, or discover."}` ).
    ENDCASE.

  ENDMETHOD.
ENDCLASS.
