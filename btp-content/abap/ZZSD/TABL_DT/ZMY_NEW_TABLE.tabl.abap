@EndUserText.label : 'My New Custom Table'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zmy_new_table {

  key client            : abap.clnt not null;
  key zzindex           : abap.numc(7) not null;
  zzmarket_restype      : abap.char(4);
  kotabnr               : abap.numc(3);
  mtart                 : abap.char(4);
  ismrefmdprfam         : abap.char(18);
  ismrefmdprod          : abap.char(18);
  zzmatnr               : abap.char(18);
  identcode             : abap.char(18);
  zzpubl_for            : abap.char(18);
  zzspart               : abap.char(2);
  ismimprint            : abap.char(10);
  ismlanguages          : abap.char(4);
  zzlang_code           : abap.char(30);
  ismmediatype          : abap.char(2);
  prctr                 : abap.char(10);
  zzprod_attribute      : abap.char(30);
  zzherkl               : abap.char(3);
  ismeditionnum         : abap.numc(6);
  zzedition_ver         : abap.char(30);
  zzvkorg               : abap.char(4);
  zzkunnr               : abap.char(10);
  zzland1               : abap.char(3);
  regio                 : abap.char(3);
  zzkdgrp               : abap.char(2);
  kdkg4                 : abap.char(2);
  zzkatr1               : abap.char(2);
  zzlea                 : abap.char(30);
  zzsan_flg             : abap.char(1);
  zlegal                : abap.char(1);
  exclude_bom           : abap.char(1);
  material_exclusion    : abap.char(18);
  zzreferral            : abap.char(10);
  zzexclusion           : abap.char(10);
  zztextid              : abap.char(4);
  zztdname              : abap.char(16);
  validate_by           : abap.char(40);
  validate_on           : abap.char(10);
  datab                 : abap.dats;
  datbi                 : abap.dats;
  created_by            : abap.char(12);
  created_at            : timestampl;
  last_changed_by       : abap.char(12);
  last_changed_at       : timestampl;
  local_last_changed_at : timestamp;

}