@EndUserText.label : 'Parcel QAD shipment polling log'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zparcel_poll_log {

  key client            : abap.clnt not null;
  key shipment_uuid     : abap.raw(16) not null;
  shipment_reference    : abap.char(35);
  status                : abap.char(10);
  status_message        : abap.string(0);
  poll_count            : abap.int2;
  created_at            : abap.utclong;
  last_changed_at       : abap.utclong;
  local_last_changed_at : abap.utclong;

}