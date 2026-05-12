"! <p class="shorttext synchronized">Consumption model for client proxy - generated</p>
"! This class has been generated based on the metadata with namespace
"! <em>Z_PARCEL_TRAC_SRV</em>
CLASS zsc_ecc_parcel DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_v4_abs_pm_model_prov
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! <p class="shorttext synchronized">ParcelTrac</p>
      BEGIN OF tys_parcel_trac,
        "! Mandt
        mandt      TYPE c LENGTH 3,
        "! <em>Key property</em> Vbeln
        vbeln      TYPE c LENGTH 10,
        "! <em>Key property</em> Posnr
        posnr      TYPE c LENGTH 6,
        "! <em>Key property</em> SeqNum
        seq_num    TYPE c LENGTH 4,
        "! TrackNum
        track_num  TYPE c LENGTH 35,
        "! Boxes
        boxes      TYPE c LENGTH 20,
        "! CartonQty
        carton_qty TYPE p LENGTH 7 DECIMALS 3,
        "! CartonWt
        carton_wt  TYPE p LENGTH 7 DECIMALS 3,
        "! Url
        url        TYPE c LENGTH 255,
      END OF tys_parcel_trac,
      "! <p class="shorttext synchronized">List of ParcelTrac</p>
      tyt_parcel_trac TYPE STANDARD TABLE OF tys_parcel_trac WITH DEFAULT KEY.


    CONSTANTS:
      "! <p class="shorttext synchronized">Internal Names of the entity sets</p>
      BEGIN OF gcs_entity_set,
        "! ParcelTracSet
        "! <br/> Collection of type 'ParcelTrac'
        parcel_trac_set TYPE /iwbep/if_cp_runtime_types=>ty_entity_set_name VALUE 'PARCEL_TRAC_SET',
      END OF gcs_entity_set .

    CONSTANTS:
      "! <p class="shorttext synchronized">Internal names for entity types</p>
      BEGIN OF gcs_entity_type,
        "! <p class="shorttext synchronized">Internal names for ParcelTrac</p>
        "! See also structure type {@link ..tys_parcel_trac}
        BEGIN OF parcel_trac,
          "! <p class="shorttext synchronized">Navigation properties</p>
          BEGIN OF navigation,
            "! Dummy field - Structure must not be empty
            dummy TYPE int1 VALUE 0,
          END OF navigation,
        END OF parcel_trac,
      END OF gcs_entity_type.


    METHODS /iwbep/if_v4_mp_basic_pm~define REDEFINITION.


  PRIVATE SECTION.

    "! <p class="shorttext synchronized">Model</p>
    DATA mo_model TYPE REF TO /iwbep/if_v4_pm_model.


    "! <p class="shorttext synchronized">Define ParcelTrac</p>
    "! @raising /iwbep/cx_gateway | <p class="shorttext synchronized">Gateway Exception</p>
    METHODS def_parcel_trac RAISING /iwbep/cx_gateway.

ENDCLASS.



CLASS ZSC_ECC_PARCEL IMPLEMENTATION.


  METHOD /iwbep/if_v4_mp_basic_pm~define.

    mo_model = io_model.
    mo_model->set_schema_namespace( 'Z_PARCEL_TRAC_SRV' ) ##NO_TEXT.

    def_parcel_trac( ).

  ENDMETHOD.


  METHOD def_parcel_trac.

    DATA:
      lo_complex_property    TYPE REF TO /iwbep/if_v4_pm_cplx_prop,
      lo_entity_type         TYPE REF TO /iwbep/if_v4_pm_entity_type,
      lo_entity_set          TYPE REF TO /iwbep/if_v4_pm_entity_set,
      lo_navigation_property TYPE REF TO /iwbep/if_v4_pm_nav_prop,
      lo_primitive_property  TYPE REF TO /iwbep/if_v4_pm_prim_prop.


    lo_entity_type = mo_model->create_entity_type_by_struct(
                                    iv_entity_type_name       = 'PARCEL_TRAC'
                                    is_structure              = VALUE tys_parcel_trac( )
                                    iv_do_gen_prim_props         = abap_true
                                    iv_do_gen_prim_prop_colls    = abap_true
                                    iv_do_add_conv_to_prim_props = abap_true ).

    lo_entity_type->set_edm_name( 'ParcelTrac' ) ##NO_TEXT.


    lo_entity_set = lo_entity_type->create_entity_set( 'PARCEL_TRAC_SET' ).
    lo_entity_set->set_edm_name( 'ParcelTracSet' ) ##NO_TEXT.


    lo_primitive_property = lo_entity_type->get_primitive_property( 'MANDT' ).
    lo_primitive_property->set_edm_name( 'Mandt' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 3 ) ##NUMBER_OK.

    lo_primitive_property = lo_entity_type->get_primitive_property( 'VBELN' ).
    lo_primitive_property->set_edm_name( 'Vbeln' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 10 ) ##NUMBER_OK.
    lo_primitive_property->set_is_key( ).

    lo_primitive_property = lo_entity_type->get_primitive_property( 'POSNR' ).
    lo_primitive_property->set_edm_name( 'Posnr' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 6 ) ##NUMBER_OK.
    lo_primitive_property->set_is_key( ).

    lo_primitive_property = lo_entity_type->get_primitive_property( 'SEQ_NUM' ).
    lo_primitive_property->set_edm_name( 'SeqNum' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 4 ) ##NUMBER_OK.
    lo_primitive_property->set_is_key( ).

    lo_primitive_property = lo_entity_type->get_primitive_property( 'TRACK_NUM' ).
    lo_primitive_property->set_edm_name( 'TrackNum' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 35 ) ##NUMBER_OK.

    lo_primitive_property = lo_entity_type->get_primitive_property( 'BOXES' ).
    lo_primitive_property->set_edm_name( 'Boxes' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 20 ) ##NUMBER_OK.

    lo_primitive_property = lo_entity_type->get_primitive_property( 'CARTON_QTY' ).
    lo_primitive_property->set_edm_name( 'CartonQty' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'Decimal' ) ##NO_TEXT.
    lo_primitive_property->set_precision( 13 ) ##NUMBER_OK.
    lo_primitive_property->set_scale( 3 ) ##NUMBER_OK.

    lo_primitive_property = lo_entity_type->get_primitive_property( 'CARTON_WT' ).
    lo_primitive_property->set_edm_name( 'CartonWt' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'Decimal' ) ##NO_TEXT.
    lo_primitive_property->set_precision( 13 ) ##NUMBER_OK.
    lo_primitive_property->set_scale( 3 ) ##NUMBER_OK.

    lo_primitive_property = lo_entity_type->get_primitive_property( 'URL' ).
    lo_primitive_property->set_edm_name( 'Url' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 255 ) ##NUMBER_OK.

  ENDMETHOD.
ENDCLASS.