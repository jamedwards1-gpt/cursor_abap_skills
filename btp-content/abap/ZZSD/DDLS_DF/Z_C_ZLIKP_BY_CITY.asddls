@AbapCatalog.sqlViewName: 'ZCZLIKPCITY_V'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Deliveries aggregated by City'

define view Z_C_ZLIKP_BY_CITY
  as select from Z_I_ZLIKP
    
    // 1. Look ONLY in the new table
    // Changing to INNER JOIN will automatically filter out missing cities
    inner join zmy_city_lookup as _NewGeoTo
      on Z_I_ZLIKP.Inco2 = _NewGeoTo.name

    // 2. Plants (Keep as Inner Join to ensure valid plants)
    inner join zmy_geo_plants as _GeoFrom
      on Z_I_ZLIKP.Vkorg = _GeoFrom.city_name
{
  key Z_I_ZLIKP.Vkorg       as SalesOrg,
  key Z_I_ZLIKP.Inco2     as ShipToCity,
  key Z_I_ZLIKP.Vstel     as ShippingPoint, 
  
  // --- SIMPLE FIELDS (No calculation) ---
  // Lat/Long fields CANNOT be keys because they are floats
  
      _NewGeoTo.lat       as ShipToLatitude,
      _NewGeoTo.lng       as ShipToLongitude,
      
      _GeoFrom.latitude   as ShipFromLatitude,
      _GeoFrom.longitude  as ShipFromLongitude,
          
      @DefaultAggregation: #SUM
      count( * )            as DeliveryCount
}
// No WHERE clause needed - INNER JOIN handles filtering

group by
  Z_I_ZLIKP.Vkorg,
  Z_I_ZLIKP.Vstel, 
  Z_I_ZLIKP.Inco2,
  _NewGeoTo.lat,
  _NewGeoTo.lng,
  _GeoFrom.latitude,
  _GeoFrom.longitude
