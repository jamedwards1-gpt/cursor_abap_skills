@EndUserText.label: 'File Upload Action Parameters'
define abstract entity ZCDS_FILE_UPLOAD_PARAMS
{
  @EndUserText.label: 'File Name'
  FileName : abap.string(0); // Kept as mandatory based on your last feedback

  @EndUserText.label: 'MIME Type'
  MimeType : abap.string(0);   // Kept as mandatory
}
