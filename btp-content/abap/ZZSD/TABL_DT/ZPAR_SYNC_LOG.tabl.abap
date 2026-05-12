@EndUserText.label : 'Log of synced Parcel Data'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zpar_sync_log {

  key client              : abap.clnt not null;
  key erp_delivery_number : vbeln not null;
  key qad_shipment_ref    : abap.char(35) not null;
  key pack_number         : abap.char(40) not null;
  synced_on               : timestampl;
  synced_by               : abap.char(12);

}