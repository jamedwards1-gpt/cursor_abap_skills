@EndUserText.label : 'City Geolocation Data'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zmy_city_lookup {

  key client  : abap.clnt not null;
  key country : abap.char(3) not null;
  key name    : abap.char(80) not null;
  key admin1  : abap.char(3) not null;
  key admin2  : abap.char(4) not null;
  lat         : abap.fltp;
  lng         : abap.fltp;

}