@EndUserText.label: 'ECC Parcel Tracking - RFC Pipe'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_PARCEL_PIPE'
  define root custom entity Z_I_Parcel_Pipe
  {
    key Vbeln      : abap.char(10);
    key Posnr      : abap.char(6);
    key SeqNum     : abap.char(4);
    TrackNum       : abap.char(35);
    Boxes          : abap.char(35);
    CartonQty      : abap.char(35);
    CartonWt       : abap.char(35);
    Url            : abap.char(255);
    DocketDate     : abap.dats;
    Status         : abap.char(20);
  } 
