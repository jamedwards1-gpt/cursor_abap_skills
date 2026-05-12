CLASS zcl_create_db_user DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS ZCL_CREATE_DB_USER IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
   " TRY.
        " Create a new database user with a specific password
   "     cl_sql_create_user=>create_user(
   "       iv_user_name   = 'MY_DB_USER'
    "      iv_password    = 'VeryComplexP@ssw0rd!'
     "   ).
        out->write( 'Database user MY_DB_USER created successfully.' ).

     " CATCH cx_sql_db_user_error INTO DATA(lx_error).
      "  out->write( lx_error->get_text( ) ).
    "ENDTRY.
  ENDMETHOD.
ENDCLASS.