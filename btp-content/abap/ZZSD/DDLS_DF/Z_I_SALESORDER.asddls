@AbapCatalog.sqlViewName: 'Z_I_SALESO'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Interface View'
@Metadata.ignorePropagatedAnnotations: true
define view Z_I_SalesOrder_V as select from zsos
{
      key so_number,
      key so_item_number,
        erp_delivery_number,
        received_at,
        status,
        material,
        last_processed_at,
        status_message,
        quantity,
        unit_of_measure,
        is_eu_compliant,
        delivery_date
}
