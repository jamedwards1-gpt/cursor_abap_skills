@EndUserText.label : 'Parcel tracking in ECC'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcup_parcel_trac {

  key client : abap.clnt not null;
  key vbeln  : vbeln not null;
  key posnr  : posnr not null;
  seq_num    : abap.char(4);
  track_num  : abap.char(35);
  boxes      : abap.char(35);
  carton_qty : abap.char(35);
  carton_wt  : abap.char(35);
  url        : abap.char(200);
  status     : abap.char(20);

}