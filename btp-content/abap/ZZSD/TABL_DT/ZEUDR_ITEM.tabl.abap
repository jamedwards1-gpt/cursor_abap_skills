@EndUserText.label : 'EUDR Assessment Items'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zeudr_item {

  key client       : abap.clnt not null;
  key osapiens_key : abap.char(36) not null;
  key item_key     : abap.char(36) not null;
  product_id       : abap.char(20);
  cn_code          : abap.char(20);
  commodities      : abap.string(0);

}