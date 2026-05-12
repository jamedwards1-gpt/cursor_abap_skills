CLASS zcl_log_test DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_rt_run.
    INTERFACES if_apj_dt_defaults.
    TYPES: BEGIN OF ty_name_range,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE c LENGTH 50,
             high   TYPE c LENGTH 50,
           END OF ty_name_range,
           ty_name_ranges TYPE STANDARD TABLE OF ty_name_range WITH EMPTY KEY.
    DATA numbers_available TYPE abap_bool VALUE abap_true.
    DATA numbers TYPE RANGE OF i.
    DATA names_available TYPE abap_bool VALUE abap_true.
    DATA names TYPE ty_name_ranges.
    DATA text TYPE c LENGTH 255.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_LOG_TEST IMPLEMENTATION.


  METHOD if_apj_dt_defaults~get_default_values.
    numbers_available = abap_true.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '42' ) TO numbers.
    names_available = abap_true.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = 'John Doe' ) TO names.
    text = 'Default processing text'.
  ENDMETHOD.


  METHOD if_apj_rt_run~execute.
    TRY.
    wait up to 8 seconds.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.