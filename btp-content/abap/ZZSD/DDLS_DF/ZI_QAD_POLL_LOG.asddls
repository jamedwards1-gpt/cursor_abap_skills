@AbapCatalog.sqlViewName: 'ZIQADPOLLLOG'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Polling Log for QAD Shipments'
define view ZI_QAD_POLL_LOG
  as select from zqad_poll_log
{
  key shipment_uuid,
      shipment_reference,
      status,
      status_message,
      poll_count,
      @Semantics.systemDateTime.createdAt: true
      created_at,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at
}
