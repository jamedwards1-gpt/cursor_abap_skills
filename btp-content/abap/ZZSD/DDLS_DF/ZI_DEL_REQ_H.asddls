@AbapCatalog.sqlViewName: 'ZVDELREQH'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Delivery Request Header'
define view ZI_DEL_REQ_H
  as select from zdel_req_h
{
  key client,
  key request_uuid,
  erp_delivery_number,
  received_at,
  status,
  last_processed_at,
  status_message
}
