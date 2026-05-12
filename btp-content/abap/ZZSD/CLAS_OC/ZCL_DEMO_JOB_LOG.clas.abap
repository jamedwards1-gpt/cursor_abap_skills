CLASS zcl_demo_job_log DEFINITION PUBLIC FINAL CREATE PUBLIC.
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



CLASS ZCL_DEMO_JOB_LOG IMPLEMENTATION.


  METHOD if_apj_dt_defaults~get_default_values.
    numbers_available = abap_true.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '42' ) TO numbers.
    names_available = abap_true.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = 'John Doe' ) TO names.
    text = 'Default processing text'.
  ENDMETHOD.


  METHOD if_apj_rt_run~execute.
    TRY.
        DATA(l_log) = cl_bali_log=>create_with_header(
          header = cl_bali_header_setter=>create( object = 'ZMY_OBJECT'
                                                  subobject = 'ZMY_SUBOBJECT' ) ).
        IF numbers_available = abap_true AND '42' IN numbers.
          l_log->add_item( item = cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_information
            text = '42 is in the number ranges' ) ).
        ENDIF.
        IF names_available = abap_true AND names IS NOT INITIAL.
          l_log->add_item( item = cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_status
            text = |Some names are available: { lines( names ) } entries| ) ).
        ENDIF.
        l_log->add_item( item = cl_bali_free_text_setter=>create(
          severity = if_bali_constants=>c_severity_status
          text = 'testing' ) ).
        cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection(
          log = l_log
          assign_to_current_appl_job = abap_true ).
      CATCH cx_bali_runtime INTO DATA(lx_bali).
        RAISE EXCEPTION TYPE cx_apj_rt
          EXPORTING previous = lx_bali.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.