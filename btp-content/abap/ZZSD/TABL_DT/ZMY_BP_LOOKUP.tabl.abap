@EndUserText.label : 'Business Partner Lookup Data'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zmy_bp_lookup {

  key client : abap.clnt not null;
  key kunnr  : abap.char(10) not null;
  country    : abap.char(3);

}