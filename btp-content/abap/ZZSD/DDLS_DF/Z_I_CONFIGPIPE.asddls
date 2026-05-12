@EndUserText.label: 'Config Pipe Custom Entity'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_CONFIG_PIPE'
define root custom entity Z_I_ConfigPipe
{
  @EndUserText.label: 'Table Name'
  key TableName : abap.char(16);
  
  @EndUserText.label: 'JSON Payload'
  ConfigJson    : abap.string(0);
  
  @EndUserText.label: 'Record Count'
  LineCount     : abap.int4;
}
