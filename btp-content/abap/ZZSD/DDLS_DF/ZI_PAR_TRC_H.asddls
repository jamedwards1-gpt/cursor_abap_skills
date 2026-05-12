@AbapCatalog.sqlViewName: 'ZVPARTRCH' 
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED 
@EndUserText.label: 'Interface View for Parcel Tracking Header'
define view ZI_PAR_TRC_H
  as select from zpar_trc_h 
{
  key client,
  key erp_delivery_number,
  qad_shipment_ref,
  shipper_id
}
