@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consolidated Parcel Data for Sync'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_BTP_ParcelSync 
  as select from zpar_trc_h as Header
  inner join zpar_trc_p as Package 
    on Header.erp_delivery_number = Package.erp_delivery_number
    and Header.qad_shipment_ref = Package.qad_shipment_ref
{
    key Header.erp_delivery_number as Vbeln,
    key Package.pack_number        as PackNumber,
    
    Header.qad_shipment_ref        as QadRef,
    Package.tracking_number        as TrackNum,
    Package.weight                 as Weight,
    Package.weight_uom             as Uom,
    Header.despatch_date           as DespatchDate
}
