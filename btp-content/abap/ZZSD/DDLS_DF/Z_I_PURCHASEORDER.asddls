@AbapCatalog.sqlViewName: 'Z_I_PURCHASEO'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Interface View'
@Metadata.ignorePropagatedAnnotations: true
define view Z_I_PurchaseOrder_V as select from zpos
{
      key po_number,
      key po_item_number,
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
