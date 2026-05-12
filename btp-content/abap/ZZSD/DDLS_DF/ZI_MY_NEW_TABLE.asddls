@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for ZMY_NEW_TABLE'
// Optional: @ObjectModel.semanticKey: [ 'zzindex' ] // Can be useful for Fiori apps to identify instances
define root view entity ZI_MY_NEW_TABLE
  as select from zmy_new_table // Your database table name
{
  // Explicitly select client, even if not part of the view's defined key here
   // Field from the base table zmy_new_table

  key zzindex, // The primary key for this view entity
      zzmarket_restype,
      kotabnr,
      mtart,
      ismrefmdprfam,
      ismrefmdprod,
      zzmatnr,
      identcode,
      zzpubl_for,
      zzspart,
      ismimprint,
      ismlanguages,
      zzlang_code,
      ismmediatype,
      prctr,
      zzprod_attribute,
      zzherkl,
      ismeditionnum,
      zzedition_ver,
      zzvkorg,
      zzkunnr,
      zzland1,
      regio,
      zzkdgrp,
      kdkg4,
      zzkatr1,
      zzlea,
      zzsan_flg,
      zlegal,
      exclude_bom,
      material_exclusion,
      zzreferral,
      zzexclusion,
      zztextid,
      zztdname,
      validate_by,
      validate_on,
      datab,
      datbi,

      // Admin fields - annotations for managed behavior
      @Semantics.user.createdBy: true
      created_by,
      @Semantics.systemDateTime.createdAt: true
      created_at,
      @Semantics.user.lastChangedBy: true
      last_changed_by,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at
}
