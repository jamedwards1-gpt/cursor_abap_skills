CLASS zcx_qad_integration_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check  " Or cx_dynamic_check if you prefer not to declare in RAISING clauses
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg. " For using attributes in messages like &FIELD_NAME&

    CONSTANTS:
      BEGIN OF missing_mandatory_field,
        msgid TYPE symsgid VALUE 'ZMSG_QAD_OUTPUT',  " Ensure this message class exists
        msgno TYPE symsgno VALUE '001',            " And this message number
        attr1 TYPE scx_attrname VALUE 'FIELD_NAME',  " For placeholder &FIELD_NAME& or &1
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_mandatory_field,

      BEGIN OF api_call_failed,
        msgid TYPE symsgid VALUE 'ZMSG_QAD_OUTPUT',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE 'REASON',     " For placeholder &REASON& or &1
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF api_call_failed,

      BEGIN OF xml_parsing_error,
        msgid TYPE symsgid VALUE 'ZMSG_QAD_OUTPUT',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE 'REASON',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF xml_parsing_error,

      BEGIN OF qad_returned_error,
        msgid TYPE symsgid VALUE 'ZMSG_QAD_OUTPUT',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE 'ERROR_TEXT',
        attr2 TYPE scx_attrname VALUE 'ERROR_NUMBER',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF qad_returned_error,

      BEGIN OF sps_response_not_found,
        msgid TYPE symsgid VALUE 'ZMSG_QAD_OUTPUT',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF sps_response_not_found,

      BEGIN OF http_call_failed,
        msgid TYPE symsgid VALUE 'ZMSG_QAD_OUTPUT',
        msgno TYPE symsgno VALUE '006',
        attr1 TYPE scx_attrname VALUE 'STATUS_CODE',
        attr2 TYPE scx_attrname VALUE 'REASON_PHRASE',
        attr3 TYPE scx_attrname VALUE 'BODY',
        attr4 TYPE scx_attrname VALUE '',
      END OF http_call_failed.

    DATA:
      field_name    TYPE string READ-ONLY,
      reason        TYPE string READ-ONLY,
      error_text    TYPE string READ-ONLY,
      error_number  TYPE string READ-ONLY,
      status_code   TYPE string READ-ONLY,
      reason_phrase TYPE string READ-ONLY,
      body          TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid         LIKE if_t100_message=>t100key OPTIONAL
        !previous       LIKE previous OPTIONAL
        !field_name     TYPE string OPTIONAL
        !reason         TYPE string OPTIONAL
        !error_text     TYPE string OPTIONAL
        !error_number   TYPE string OPTIONAL
        !status_code    TYPE string OPTIONAL
        !reason_phrase  TYPE string OPTIONAL
        !body           TYPE string OPTIONAL.
ENDCLASS.



CLASS ZCX_QAD_INTEGRATION_ERROR IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).

    me->field_name    = field_name.
    me->reason        = reason.
    me->error_text    = error_text.
    me->error_number  = error_number.
    me->status_code   = status_code.
    me->reason_phrase = reason_phrase.
    me->body          = body.

    CLEAR me->textid. " Needs to be cleared before being set by IF_T100_MESSAGE
    IF textid IS INITIAL.
      " Fallback to a generic message from your message class if no specific textid is provided
      if_t100_message~t100key = VALUE #( msgid = 'ZMSG_QAD_OUTPUT' msgno = '000' ). "Ensure ZMSG_QAD_OUTPUT and 000 exist
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.