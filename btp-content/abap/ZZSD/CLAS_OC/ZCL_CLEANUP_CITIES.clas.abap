CLASS zcl_cleanup_cities DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    METHODS delete_data.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CLEANUP_CITIES IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    " Execute the cleanup logic
    delete_data( ).
    out->write( 'Deletion process completed for both tables.' ).
  ENDMETHOD.


  METHOD delete_data.
    " ERROR FIX EXPLANATION:
    " The internal table used in 'DELETE dbtab FROM TABLE itab' must
    " match the structure of the database table, or at least the primary keys.
    " The safest way is to declare the internal table TYPE STANDARD TABLE OF <dbtab>.

    " 1. Declare tables for ZLIKP
    DATA: lt_zlikp_to_delete TYPE STANDARD TABLE OF zlikp.

    " 2. Declare tables for the second table (assuming ZCITIES based on class name)
    " Replace 'zcities' with your actual second table name
    DATA: lt_cities_to_delete TYPE STANDARD TABLE OF zmy_city_lookup.


    " --- STEP A: SELECT DATA TO DELETE ---

    " Select the records you want to delete from ZLIKP
    " (Add a WHERE clause here if you shouldn't delete everything)
    SELECT * FROM zlikp INTO TABLE @lt_zlikp_to_delete.

    " Select the records you want to delete from the second table
    SELECT * FROM zmy_city_lookup INTO TABLE @lt_cities_to_delete.


    " --- STEP B: DELETE FROM FIRST TABLE (ZLIKP) ---

    IF lt_zlikp_to_delete IS NOT INITIAL.
      " This works because lt_zlikp_to_delete has the exact structure of ZLIKP
      DELETE zlikp FROM TABLE @lt_zlikp_to_delete.

      " Alternatively, if you only have keys, ensure the structure matches the Key Fields exactly.
    ENDIF.


    " --- STEP C: DELETE FROM SECOND TABLE ---

    IF lt_cities_to_delete IS NOT INITIAL.
      DELETE zmy_city_lookup FROM TABLE @lt_cities_to_delete.
    ENDIF.

    " Commit the changes to the database
    COMMIT WORK.

  ENDMETHOD.
ENDCLASS.