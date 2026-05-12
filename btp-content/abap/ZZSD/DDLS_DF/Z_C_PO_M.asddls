@EndUserText.label: 'Purchase Order Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'po_number' ]
@UI.headerInfo: { typeName: 'Purchase Order', typeNamePlural: 'Purchase Orders' } // <-- Add this
define root view entity Z_C_PO_M
  provider contract transactional_query
  as projection on Z_I_PO_M
{
  @UI.lineItem: [ { position: 10, label: 'PO Number' } ]
  key po_number,
  @UI.lineItem: [ { position: 20, label: 'Item' } ]
  key po_item_number,
  @UI.lineItem: [ { position: 30, label: 'Delivery number' } ]
  erp_delivery_number,
  @UI.lineItem: [ { position: 40, label: 'Received at' } ]
  received_at,
  @UI.lineItem: [ { position: 50, label: 'Status' } ]
  status,
  @UI.lineItem: [ { position: 60, label: 'Material' } ]
  material,
  @UI.lineItem: [ { position: 70, label: 'Last processed' } ]
  last_processed_at,
  @UI.lineItem: [ { position: 80, label: 'Message' } ]
  status_message,
  @UI.lineItem: [ { position: 90, label: 'Quantity' } ]
  quantity,
  @UI.lineItem: [ { position: 100, label: 'UOM' } ]
  unit_of_measure,
  @UI.lineItem: [ { position: 110, label: 'EU Compliant' } ]
  is_eu_compliant,
  @UI.lineItem: [ { position: 120, label: 'Delivery Date' } ] 
  delivery_date
}
