CLASS zcl_calculate_so_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CALCULATE_SO_STATUS IMPLEMENTATION.


METHOD if_rap_query_provider~select.

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

  " --- Explicit State Cursors ---
  DATA po_cursor TYPE i.
  po_cursor = 1.
  DATA so_cursor TYPE i.
  so_cursor = 1.
  " --- End of State Cursors ---

  DATA lt_results TYPE STANDARD TABLE OF Z_CE_SalesOrderStatus.

  " 3. Process each Sales Order using a robust WHILE loop
  WHILE so_cursor <= lines( lt_sales_orders ).
    ASSIGN lt_sales_orders[ so_cursor ] TO FIELD-SYMBOL(<fs_so>).

    " --- All variables for a single SO are declared here to ensure they are reset for each loop pass ---
    DATA ls_result TYPE Z_CE_SalesOrderStatus.
    ls_result = CORRESPONDING #( <fs_so> ).

    DATA qty_to_fulfill TYPE zpos-quantity.
    qty_to_fulfill = <fs_so>-quantity.

    DATA would_block TYPE abap_boolean.
    would_block = abap_false.

    DATA blocking_po    TYPE zpos-po_number.
    DATA fulfilling_pos TYPE STANDARD TABLE OF string WITH EMPTY KEY.
     CLEAR fulfilling_pos.
    DATA(temp_po_cursor) = po_cursor.
    " --- End of local variable declarations ---


    " --- Step A: "Look-ahead" dry run to determine status ---
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

    " --- Step B: Set status and perform actual stock consumption ---
    qty_to_fulfill = <fs_so>-quantity.
    IF would_block = abap_true.
      ls_result-status = 'Blocked'.
      ls_result-status_message = |Blocked by non-compliant PO: { blocking_po }|.
    ELSE.
      ls_result-status = 'Released'.
      WHILE qty_to_fulfill > 0.
        READ TABLE lt_po_queue INDEX po_cursor ASSIGNING FIELD-SYMBOL(<fs_po_consume>).
        IF sy-subrc <> 0.
          ls_result-status = 'Blocked'.
          ls_result-status_message = 'Insufficient stock to fulfill order'.
          EXIT.
        ENDIF.

        IF <fs_po_consume>-remaining_qty <= 0 OR <fs_po_consume>-material <> <fs_so>-material.
          po_cursor += 1.
          CONTINUE.
        ENDIF.

        DATA(qty_to_take) = COND #( WHEN qty_to_fulfill > <fs_po_consume>-remaining_qty
                                    THEN <fs_po_consume>-remaining_qty
                                    ELSE qty_to_fulfill ).

        IF qty_to_take > 0.
          READ TABLE fulfilling_pos WITH KEY table_line = <fs_po_consume>-po_number TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            APPEND <fs_po_consume>-po_number TO fulfilling_pos.
          ENDIF.
        ENDIF.

        <fs_po_consume>-remaining_qty -= qty_to_take.
        qty_to_fulfill -= qty_to_take.

        IF <fs_po_consume>-remaining_qty <= 0.
          po_cursor += 1.
        ENDIF.
      ENDWHILE.
      IF ls_result-status = 'Released'.
         ls_result-status_message = |Fulfilled by PO(s): { concat_lines_of( table = fulfilling_pos sep = ', ' ) }|.
      ENDIF.
    ENDIF.

    APPEND ls_result TO lt_results.
    so_cursor += 1. " Advance to the next Sales Order
  ENDWHILE.

  " --- Final Paging Step ---
  io_response->set_total_number_of_records( lines( lt_results ) ).
  DATA(paging) = io_request->get_paging( ).
  IF paging IS BOUND.
      DATA(offset) = paging->get_offset( ).
      DATA(page_size) = paging->get_page_size( ).
      DATA paged_results LIKE lt_results.
      IF page_size > 0.
          DATA(lv_from) = offset + 1.
          DATA(lv_to)   = offset + page_size.
          LOOP AT lt_results ASSIGNING FIELD-SYMBOL(<fs_result_line>) FROM lv_from TO lv_to.
            APPEND <fs_result_line> TO paged_results.
          ENDLOOP.
          io_response->set_data( paged_results ).
      ELSE.
          io_response->set_data( lt_results ).
      ENDIF.
  ELSE.
    io_response->set_data( lt_results ).
  ENDIF.

ENDMETHOD.
ENDCLASS.