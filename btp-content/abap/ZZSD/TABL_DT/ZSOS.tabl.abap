@EndUserText.label : 'Sales Order Table'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zsos {

  key client          : abap.clnt not null;
  key so_number       : abap.char(10) not null;
  key so_item_number  : abap.char(6) not null;
  erp_delivery_number : vbeln;
  received_at         : timestampl;
  status              : abap.char(20);
  last_processed_at   : timestampl;
  material            : matnr;
  status_message      : abap.string(0);
  @Semantics.quantity.unitOfMeasure : 'zpos.unit_of_measure'
  quantity            : abap.quan(13,2);
  unit_of_measure     : meins;
  is_eu_compliant     : abap_boolean;
  delivery_date       : abap.dats;

}