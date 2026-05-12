CLASS zcl_run_delivery_job_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_RUN_DELIVERY_JOB_HANDLER IMPLEMENTATION.


METHOD if_http_service_extension~handle_request.

  " Only execute if the request is a POST
  IF request->get_method( ) <> 'POST'.
    response->set_status( i_code = 405 i_reason = 'Method Not Allowed' ).
    RETURN.
  ENDIF.

  " 1. Prepare FIFO Queues
  SELECT * FROM Z_I_PurchaseOrder_v ORDER BY delivery_date, po_number INTO TABLE @DATA(lt_purchase_orders).
  SELECT * FROM Z_I_SalesOrder_v    ORDER BY delivery_date, so_number INTO TABLE @DATA(lt_sales_orders).

  " 2. Initialize a stateful PO queue
  TYPES: BEGIN OF ty_po_state,
           po_number       TYPE zpos-po_number,
           material        TYPE zpos-material,
           is_eu_compliant TYPE abap_boolean,
           remaining_qty   TYPE zpos-quantity,
         END OF ty_po_state.
  DATA lt_po_queue TYPE STANDARD TABLE OF ty_po_state.
  lt_po_queue = CORRESPONDING #( lt_purchase_orders MAPPING remaining_qty = quantity ).

  DATA po_cursor TYPE i.
  po_cursor = 1.
  DATA so_cursor TYPE i.
  so_cursor = 1.

  " --- CHANGE #1: Declare the table as a 'RANGE' type ---
  DATA released_so_keys TYPE RANGE OF zsos-so_number.

  " 3. Run the full simulation logic
  WHILE so_cursor <= lines( lt_sales_orders ).
    ASSIGN lt_sales_orders[ so_cursor ] TO FIELD-SYMBOL(<fs_so>).
    DATA ls_result TYPE Z_CE_SalesOrderStatus.
    ls_result = CORRESPONDING #( <fs_so> ).

    DATA qty_to_fulfill TYPE zpos-quantity.
    qty_to_fulfill = <fs_so>-quantity.
    DATA would_block TYPE abap_boolean.
    would_block = abap_false.
    DATA blocking_po    TYPE zpos-po_number.

    DATA(temp_po_cursor) = po_cursor.
    LOOP AT lt_po_queue ASSIGNING FIELD-SYMBOL(<fs_po_dry_run>) FROM temp_po_cursor.
      IF <fs_po_dry_run>-material <> <fs_so>-material OR <fs_po_dry_run>-remaining_qty <= 0.
        temp_po_cursor += 1.
        CONTINUE.
      ENDIF.
      IF <fs_so>-is_eu_compliant = abap_true AND <fs_po_dry_run>-is_eu_compliant = abap_false.
        would_block = abap_true.
        blocking_po = <fs_po_dry_run>-po_number.
        EXIT.
      ENDIF.
      qty_to_fulfill -= <fs_po_dry_run>-remaining_qty.
      IF qty_to_fulfill <= 0.
        EXIT.
      ENDIF.
    ENDLOOP.

    qty_to_fulfill = <fs_so>-quantity.
    IF would_block = abap_false.
      ls_result-status = 'Released'.
      WHILE qty_to_fulfill > 0.
        READ TABLE lt_po_queue INDEX po_cursor ASSIGNING FIELD-SYMBOL(<fs_po_consume>).
        IF sy-subrc <> 0.
          ls_result-status = 'Blocked'.
          EXIT.
        ENDIF.
        IF <fs_po_consume>-remaining_qty <= 0 OR <fs_po_consume>-material <> <fs_so>-material.
          po_cursor += 1.
          CONTINUE.
        ENDIF.
        DATA(qty_to_take) = COND #( WHEN qty_to_fulfill > <fs_po_consume>-remaining_qty THEN <fs_po_consume>-remaining_qty ELSE qty_to_fulfill ).
        <fs_po_consume>-remaining_qty -= qty_to_take.
        qty_to_fulfill -= qty_to_take.
        IF <fs_po_consume>-remaining_qty <= 0.
          po_cursor += 1.
        ENDIF.
      ENDWHILE.
    ENDIF.

    IF ls_result-status = 'Released'.
      " --- CHANGE #2: Populate the ranges table with the correct structure ---
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_so>-so_number ) TO released_so_keys.
    ENDIF.
    so_cursor += 1.
  ENDWHILE.

  " --- 4. Save the results to the database ---
  LOOP AT lt_po_queue INTO DATA(po_state).
    UPDATE zpos SET quantity = @po_state-remaining_qty
      WHERE po_number = @po_state-po_number.
  ENDLOOP.

  IF released_so_keys IS NOT INITIAL.
    " --- CHANGE #3: Use the modern DELETE ... IN statement ---
    DELETE FROM zsos WHERE so_number IN @released_so_keys.
  ENDIF.

  " Send a success response back to the caller
  response->set_status( i_code = 200 i_reason = 'OK' ).
  response->set_text( 'Delivery job completed successfully.' ).

ENDMETHOD.
ENDCLASS.