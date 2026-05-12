@EndUserText.label : 'POC - ERP Parcel Data Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zpar_trc_h {

  key client              : abap.clnt not null;
  key erp_delivery_number : vbeln not null;
  key qad_shipment_ref    : abap.char(35) not null;
  shipper_id              : abap.char(10);
  trax_client             : abap.char(10);
  service_code            : abap.char(10);
  global_carrier_code     : abap.char(10);
  despatch_date           : abap.dats;
  total_charge_sell       : abap.dec(16,2);
  currency_code           : abap.cuky;

}