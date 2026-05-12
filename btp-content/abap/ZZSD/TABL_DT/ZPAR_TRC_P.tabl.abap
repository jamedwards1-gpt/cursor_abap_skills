@EndUserText.label : 'POC - ERP Parcel Data - Packages'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zpar_trc_p {

  key client              : abap.clnt not null;
  key erp_delivery_number : vbeln not null;
  key qad_shipment_ref    : abap.char(35) not null;
  key pack_number         : abap.char(40) not null;
  tracking_number         : abap.char(50);
  master_tracking_number  : abap.char(50);
  weight                  : abap.dec(16,6);
  weight_uom              : abap.unit(3);

}