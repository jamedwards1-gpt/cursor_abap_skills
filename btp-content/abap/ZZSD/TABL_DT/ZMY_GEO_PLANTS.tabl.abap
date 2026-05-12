@EndUserText.label : 'Geo-Locations for Cities'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zmy_geo_plants {

  key client    : abap.clnt not null;
  key city_name : abap.char(100) not null;
  latitude      : abap.fltp;
  longitude     : abap.fltp;

}