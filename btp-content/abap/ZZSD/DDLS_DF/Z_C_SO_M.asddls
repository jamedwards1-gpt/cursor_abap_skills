@EndUserText.label: 'Sales Order Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'so_number', 'so_item_number' ]
@UI.headerInfo: { typeName: 'Sales Order', typeNamePlural: 'Sales Orders' }
define root view entity Z_C_SO_M
  provider contract transactional_query
  as projection on Z_I_SO_M
{
  @UI.lineItem: [ { position: 10, label: 'SO Number' } ]
  key so_number,
  @UI.lineItem: [ { position: 20, label: 'Item' } ]
  key so_item_number,
  @UI.lineItem: [ { position: 30, label: 'Delivery number' } ]
  erp_delivery_number,
  @UI.lineItem: [ { position: 40, label: 'Received at' } ]
  received_at,
  @UI.lineItem: [ { position: 50, label: 'Status' } ]
  status,
  @UI.lineItem: [ { position: 60, label: 'Last processed' } ]
  material,
  @UI.lineItem: [ { position: 70, label: 'Material' } ]
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
