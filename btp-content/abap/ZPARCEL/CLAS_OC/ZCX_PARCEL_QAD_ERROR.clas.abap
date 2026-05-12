CLASS zcx_parcel_qad_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.

    DATA gv_message TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid   LIKE if_t100_message=>t100key OPTIONAL
        !previous LIKE previous OPTIONAL
        !message  TYPE string OPTIONAL.

  PRIVATE SECTION. " <<< ADDED EMPTY PRIVATE SECTION
ENDCLASS.



CLASS ZCX_PARCEL_QAD_ERROR IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->gv_message = message. " Maps the importing parameter 'message' to the attribute
    me->if_t100_message~t100key = COND #( WHEN textid IS SUPPLIED AND textid IS NOT INITIAL THEN textid
                                          ELSE VALUE #( msgid = 'SY' msgno = '396' ) ). " SY-396: Unspecified error
  ENDMETHOD.
ENDCLASS.