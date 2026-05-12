@AbapCatalog.sqlViewName: 'Z_I_PARDATA_VW'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Joined Parcel Header, Package, and Delivery Data'

define view Z_I_PARCEL_DATA 
  as select from zpar_trc_h as Header
  
  // --- Join 1: Parcels to Packages (Existing) ---
  inner join zpar_trc_p as Package
    on  Header.client              = Package.client
    and Header.erp_delivery_number = Package.erp_delivery_number
    and Header.qad_shipment_ref    = Package.qad_shipment_ref
    
  // --- Join 2: Parcels to Deliveries (New Enrichment) ---
  left outer join zlikp as Delivery
    on  Header.client              = Delivery.client
    and Header.erp_delivery_number = lpad( Delivery.vbeln, 10, '0' )
    
{
  // --- Key Fields ---
  key Header.client,
  key Header.erp_delivery_number,
  key Header.qad_shipment_ref,
  key Package.pack_number,
  
  // --- Fields from Header Table ---
  Header.shipper_id,
  Header.trax_client,
  Header.service_code,
  Header.global_carrier_code,
  Header.despatch_date,
  Header.total_charge_sell,
  Header.currency_code,
  
  // --- Fields from Package Table ---
  Package.tracking_number,
  Package.master_tracking_number,
  Package.weight,
  Package.weight_uom,

  // --- NEW: Fields from Delivery Table (zlikp) ---
  
  Delivery.vstel,   // Shipping Point
  Delivery.route,   // Route
  Delivery.vkorg,   // Ship-to party
  Delivery.inco1,   // Ship-to party
  Delivery.kunnr,   // Ship-to party 
  Delivery.kunag,
  Delivery.wadat,   // Planned goods issue date
  Delivery.lfart    // Delivery Type
 
  
}
