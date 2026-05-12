@AbapCatalog.sqlViewName: 'ZVCUPPARTRC'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Parcel Tracking Details'
define view ZI_CUP_PARCEL_TRAC
  as select from zcup_parcel_trac
{
  key client,
  key vbeln, // ERP Delivery Number
  key posnr, // ERP Delivery Item Number
  seq_num,
  track_num,
  boxes,
  carton_qty,
  carton_wt,
  url
}
