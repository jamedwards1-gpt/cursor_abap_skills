@AbapCatalog.sqlViewName: 'Z_ZLIKP_V'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZLIKP odata service'
@Metadata.ignorePropagatedAnnotations: true
define view Z_I_ZLIKP as select from zlikp
{
       @EndUserText.label: 'Delivery'
   key vbeln as Vbeln,
       
       @EndUserText.label: 'Created by'
       ernam as Ernam,
       
       @EndUserText.label: 'Creation time'
       erzet as Erzet,
       
       @EndUserText.label: 'Creation date'
       erdat as Erdat,
       
       @EndUserText.label: 'Sales district'
       bzirk as Bzirk,
       
       @EndUserText.label: 'Shipping Point'
       vstel as Vstel,
       
       @EndUserText.label: 'Sales Organization'
       vkorg as Vkorg,
       
       @EndUserText.label: 'Delivery Type'
       lfart as Lfart,
       
       @EndUserText.label: 'Complete delivery'
       autlf as Autlf,
       
       @EndUserText.label: 'Order combination'
       kzazu as Kzazu,
       
       @EndUserText.label: 'Goods Issue Date'
       wadat as Wadat,
       
       @EndUserText.label: 'Loading Date'
       lddat as Lddat,
       
       @EndUserText.label: 'Transp. Planning Date'
       tddat as Tddat,
       
       @EndUserText.label: 'Delivery Date'
       lfdat as Lfdat,
       
       @EndUserText.label: 'Picking Date'
       kodat as Kodat,
       
       @EndUserText.label: 'Unloading Point'
       ablad as Ablad,
       
       @EndUserText.label: 'Incoterms (Part 1)'
       inco1 as Inco1,
       
       @EndUserText.label: 'Incoterms (Part 2)'
       inco2 as Inco2,
       
       @EndUserText.label: 'Export indicator'
       expkz as Expkz,
       
       @EndUserText.label: 'Route'
       route as Route,
       
       @EndUserText.label: 'Billing Block'
       faksk as Faksk,
       
       @EndUserText.label: 'Delivery Block'
       lifsk as Lifsk,
       
       @EndUserText.label: 'Document Category'
       vbtyp as Vbtyp,
       
       @EndUserText.label: 'Cust. acct assignment'
       knfak as Knfak,
       
       @EndUserText.label: 'Transportation qual.'
       tpqua as Tpqua,
       
       @EndUserText.label: 'Transportation group'
       tpgrp as Tpgrp,
       
       @EndUserText.label: 'Delivery Priority'
       lprio as Lprio,
       
       @EndUserText.label: 'Shipping conditions'
       vsbed as Vsbed,
       
       @EndUserText.label: 'Ship-to party'
       kunnr as Kunnr,
       
       @EndUserText.label: 'Sold-to party'
       kunag as Kunag,
       
       @EndUserText.label: 'Customer group'
       kdgrp as Kdgrp,
       
       @EndUserText.label: 'Distance (km)'
       stzkl as Stzkl,
       
       @EndUserText.label: 'Distance (miles)'
       stzzu as Stzzu,
       
       @EndUserText.label: 'Volume unit'
       voleh as Voleh,
       
       @EndUserText.label: 'Number of packages'
       anzpk as Anzpk,
       
       @EndUserText.label: 'Picking time'
       berot as Berot,
       
       @EndUserText.label: 'Loading time'
       lfuhr as Lfuhr,
       
       @EndUserText.label: 'Weight rule'
       grulg as Grulg,
       
       @EndUserText.label: 'Loading point'
       lstel as Lstel,
       
       @EndUserText.label: 'Transportation group'
       tragr as Tragr,
       
       @EndUserText.label: 'Billing type'
       fkarv as Fkarv,
       
       @EndUserText.label: 'Billing date'
       fkdat as Fkdat,
       
       @EndUserText.label: 'Billing period'
       perfk as Perfk,
       
       @EndUserText.label: 'Route (alternative)'
       routa as Routa,
       
       @EndUserText.label: 'Update group (stats)'
       stafo as Stafo,
       
       @EndUserText.label: 'Pricing procedure'
       kalsm as Kalsm,
       
       @EndUserText.label: 'Document condition'
       knumv as Knumv,
       
       @EndUserText.label: 'Document currency'
       waerk as Waerk,
       
       @EndUserText.label: 'Sales office'
       vkbur as Vkbur,
       
       @EndUserText.label: 'Sales doc. processing'
       vbeak as Vbeak,
       
       @EndUserText.label: 'Combination criteria'
       zukrl as Zukrl,
       
       @EndUserText.label: 'Allocation number'
       verur as Verur,
       
       @EndUserText.label: 'Communication number'
       commn as Commn,
       
       @EndUserText.label: 'Statistics currency'
       stwae as Stwae,
       
       @EndUserText.label: 'Exchange rate (stats)'
       stcur as Stcur,
       
       @EndUserText.label: 'Foreign trade doc. no.'
       exnum as Exnum,
       
       @EndUserText.label: 'Changed by'
       aenam as Aenam,
       
       @EndUserText.label: 'Changed on'
       aedat as Aedat,
       
       @EndUserText.label: 'Warehouse Number'
       lgnum as Lgnum,
       
       @EndUserText.label: 'Picking list'
       lispl as Lispl,
       
       @EndUserText.label: 'Interco. sales org.'
       vkoiv as Vkoiv,
       
       @EndUserText.label: 'Interco. dist. channel'
       vtwiv as Vtwiv,
       
       @EndUserText.label: 'Interco. division'
       spaiv as Spaiv,
       
       @EndUserText.label: 'Interco. billing type'
       fkaiv as Fkaiv,
       
       @EndUserText.label: 'Interco. price list'
       pioiv as Pioiv,
       
       @EndUserText.label: 'Interco. billing div.'
       fkdiv as Fkdiv,
       
       @EndUserText.label: 'Interco. customer no.'
       kuniv as Kuniv,
       
       @EndUserText.label: 'Credit control area'
       kkber as Kkber,
       
       @EndUserText.label: 'Credit account'
       knkli as Knkli,
       
       @EndUserText.label: 'Credit rep. group'
       grupp as Grupp,
       
       @EndUserText.label: 'Credit processor'
       sbgrp as Sbgrp,
       
       @EndUserText.label: 'Credit risk category'
       ctlpc as Ctlpc,
       
       @EndUserText.label: 'Bill of Lading'
       bolnr as Bolnr,
       
       @EndUserText.label: 'Vendor'
       lifnr as Lifnr,
       
       @EndUserText.label: 'Means of transport type'
       traty as Traty,
       
       @EndUserText.label: 'Means of transport ID'
       traid as Traid,
       
       @EndUserText.label: 'Credit release date'
       cmfre as Cmfre,
       
       @EndUserText.label: 'Next credit check'
       cmngv as Cmngv,
       
       @EndUserText.label: 'GR/GI slip number'
       xabln as Xabln,
       
       @EndUserText.label: 'Document Date'
       bldat as Bldat,
       
       @EndUserText.label: 'Actual Goods Issue Date'
       wadat_ist as WadatIst,
       
       @EndUserText.label: 'Overall block status'
       trspg as Trspg,
       
       @EndUserText.label: 'Shipment number'
       tpsid as Tpsid,
       
       @EndUserText.label: 'External ID'
       lifex as Lifex,
       
       @EndUserText.label: 'Appointment number'
       ternr as Ternr,
       
       @EndUserText.label: 'Pricing procedure (CH)'
       kalsm_ch as KalsmCh,
       
       @EndUserText.label: 'Customer (CH)'
       klief as Klief
}
