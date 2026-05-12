@EndUserText.label: 'Sales Order Status (Custom Entity)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CALCULATE_SO_STATUS'
define custom entity Z_CE_SalesOrderStatus
{
  key so_number         : abap.char(10);
  key so_item_number    : abap.char(6);
  @Semantics.quantity.unitOfMeasure: 'unit_of_measure' // Annotation to link the fields
  quantity              : abap.quan(13,2);
  unit_of_measure       : meins;                         // The unit of measure field

  status                : abap.char(20);
  status_message        : abap.string(0);
}
