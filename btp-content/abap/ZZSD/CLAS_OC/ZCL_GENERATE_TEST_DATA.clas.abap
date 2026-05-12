CLASS zcl_generate_test_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS ZCL_GENERATE_TEST_DATA IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    " This 'main' method will be executed when you run the class.

    " Clear tables to ensure a fresh start on every run
    DELETE FROM zpos.
    DELETE FROM zsos.

    " 1. Create Purchase Order data (Supply)
    INSERT zpos FROM TABLE @( VALUE #(
      ( client = sy-mandt po_number = 'PO_NOM1' po_item_number = '000010' erp_delivery_number = '0080018383' received_at = ''
      status = '' last_processed_at = '' material = '0000002700185292' status_message = '' quantity = 50 is_eu_compliant = abap_true unit_of_measure = 'EA' delivery_date = '20250701' )
      ( client = sy-mandt po_number = 'PO_NOM2' po_item_number = '000010' erp_delivery_number = '0080018384' received_at = ''
      status = '' last_processed_at = '' material = '0000002700185292' status_message = '' quantity = 200 is_eu_compliant = abap_false unit_of_measure = 'EA' delivery_date = '20250702' )
      ( client = sy-mandt po_number = 'PO_NOM3' po_item_number = '000010' erp_delivery_number = '0080018385' received_at = ''
      status = '' last_processed_at = '' material = '0000002700185292' status_message = '' quantity = 100 is_eu_compliant = abap_false unit_of_measure = 'EA' delivery_date = '20250703' )
      ( client = sy-mandt po_number = 'PO_NOM3' po_item_number = '000020' erp_delivery_number = '0080018385' received_at = ''
      status = '' last_processed_at = '' material = '0000002700185292' status_message = '' quantity = 1000 is_eu_compliant = abap_true unit_of_measure = 'EA' delivery_date = '20250704' )
    ) ).
    out->write( |{ sy-dbcnt } purchase orders inserted.| ).

    " 2. Create Sales Order data (Demand)
    INSERT zsos FROM TABLE @( VALUE #(
      ( client = sy-mandt so_number = 'EU-SO-01' so_item_number = '10' quantity = 40 material = '0000002700185292' unit_of_measure = 'EA' delivery_date = '20250710' is_eu_compliant = abap_true )
      ( client = sy-mandt so_number = 'EU-SO-02' so_item_number = '10' quantity = 40 material = '0000002700185292' unit_of_measure = 'EA' delivery_date = '20250711' is_eu_compliant = abap_true )
      ( client = sy-mandt so_number = 'EU-SO-05' so_item_number = '10' quantity = 40 material = '0000002700185292' unit_of_measure = 'EA' delivery_date = '20250712' is_eu_compliant = abap_true )
      ( client = sy-mandt so_number = 'GB-SO-03' so_item_number = '10' quantity = 40 material = '0000002700185292' unit_of_measure = 'EA' delivery_date = '20250713' is_eu_compliant = abap_false )
      ( client = sy-mandt so_number = 'GB-SO-04' so_item_number = '10' quantity = 40 material = '0000002700185292' unit_of_measure = 'EA' delivery_date = '20250714' is_eu_compliant = abap_false )
      ( client = sy-mandt so_number = 'GB-SO-06' so_item_number = '10' quantity = 40 material = '0000002700185292' unit_of_measure = 'EA' delivery_date = '20250715' is_eu_compliant = abap_false )
      ( client = sy-mandt so_number = 'EU-SO-07' so_item_number = '10' quantity = 40 material = '0000002700185292' unit_of_measure = 'EA' delivery_date = '20250716' is_eu_compliant = abap_true )
      ( client = sy-mandt so_number = 'EU-SO-08' so_item_number = '10' quantity = 40 material = '0000002700185292' unit_of_measure = 'EA' delivery_date = '20250717' is_eu_compliant = abap_true )
    ) ).
    out->write( |{ sy-dbcnt } sales orders inserted.| ).

  ENDMETHOD.
ENDCLASS.