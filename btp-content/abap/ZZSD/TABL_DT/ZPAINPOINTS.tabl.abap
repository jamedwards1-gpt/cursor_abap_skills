@EndUserText.label : 'ERP Pain Points Master Data'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zpainpoints {

  key client           : abap.clnt not null;
  key id               : abap.char(50) not null;
  count_col            : abap.char(50);
  external_ref         : abap.char(100);
  sir_ticket           : abap.char(100);
  sir_status           : abap.char(50);
  potential_duplicate  : abap.char(50);
  source_ref_id        : abap.char(100);
  status_main          : abap.char(50);
  duplicate_of         : abap.char(100);
  cause                : abap.string(0);
  pain_point           : abap.string(0);
  impacts              : abap.string(0);
  column1_generic      : abap.char(255);
  column2_generic      : abap.char(255);
  review_group         : abap.char(255);
  cause_metagroup      : abap.char(255);
  cause_group          : abap.char(255);
  pain_point_group     : abap.char(255);
  impact_group         : abap.char(255);
  location             : abap.char(255);
  process              : abap.char(255);
  example              : abap.string(0);
  current_solution     : abap.string(0);
  s4hana_opportunity   : abap.string(0);
  summary              : abap.string(0);
  description          : abap.string(0);
  review               : abap.string(0);
  benefit_col          : abap.string(0);
  time_impact          : abap.char(255);
  cost_impact          : abap.char(255);
  anticipated_benefits : abap.string(0);
  ease_implementation  : abap.char(255);
  comments_delivery    : abap.string(0);
  comments_analytics   : abap.string(0);
  input_finance        : abap.string(0);
  comments_business    : abap.string(0);
  primary_sap_team     : abap.char(255);
  primary_sir_group    : abap.char(255);
  source_who           : abap.char(255);
  requestor            : abap.char(255);
  source_via           : abap.char(255);
  reference            : abap.char(255);
  source_url           : abap.string(0);

}