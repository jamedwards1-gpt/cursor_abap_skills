@EndUserText.label : 'Delivery Request Header POC'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zdel_req_h {

  key client          : abap.clnt not null;
  key request_uuid    : sysuuid_x16 not null;
  erp_delivery_number : vbeln;
  received_at         : timestampl;
  status              : abap.char(20);
  last_processed_at   : timestampl;
  status_message      : abap.string(0);

}