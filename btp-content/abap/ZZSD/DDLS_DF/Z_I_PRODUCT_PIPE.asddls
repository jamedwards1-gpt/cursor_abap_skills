@EndUserText.label: 'ECC Product Information - RFC Pipe'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_PRODUCT_PIPE'
define root custom entity Z_I_Product_Pipe
{
  key Matnr   : abap.char(18);
  Maktx       : abap.char(40);
  Mtart       : abap.char(4);
  Matkl       : abap.char(9);
  Meins       : abap.char(3);
  Mstae       : abap.char(2);
  Isbn10      : abap.char(18);
  Isbn13      : abap.char(18);
  
}
