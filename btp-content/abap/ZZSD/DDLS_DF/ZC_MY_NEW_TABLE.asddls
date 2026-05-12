@EndUserText.label: 'Projection View for My New Table'
@AccessControl.authorizationCheck: #NOT_REQUIRED // Or your preferred authorization
@Metadata.allowExtensions: true // Allows for UI extensions
define root view entity ZC_MY_NEW_TABLE
  provider contract transactional_query // Indicates it's a transactional query provider
  as projection on ZI_MY_NEW_TABLE // Projecting from your Interface View
{
  key zzindex, // Redefine the key from the underlying interface view

      // Explicitly list all fields to be projected
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

      // Admin Data Fields
      created_by,
      created_at,
      last_changed_by,
      last_changed_at,
      local_last_changed_at

      /* Associations (if any in ZI view, ensure they are listed if needed) */
      // _association_name // Make associations public from the interface view
      // If ZI_MY_NEW_TABLE has associations that should be usable in this
      // projection (e.g., for value helps or related data on the UI),
      // you would list them here as well.
}
