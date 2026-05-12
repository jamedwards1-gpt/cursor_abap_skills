@EndUserText.label : 'EUDR Assessment Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zeudr_head {

  key client       : abap.clnt not null;
  key osapiens_key : abap.char(36) not null;
  readable_id      : abap.char(20);
  activity_type    : abap.char(20);
  last_update_ts   : abap.char(30);
  assessment_ts    : abap.char(30);

}