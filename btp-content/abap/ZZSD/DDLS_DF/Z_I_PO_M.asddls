@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Managed Root'
define root view entity Z_I_PO_M
  as select from zpos
{
  key po_number,
  key po_item_number,
      erp_delivery_number,
      received_at,
      status,
      last_processed_at,
      status_message,
      material,
      @Semantics.quantity.unitOfMeasure: 'unit_of_measure' // <-- This line fixes the error
      quantity,
      unit_of_measure,
      is_eu_compliant,
      delivery_date
}
