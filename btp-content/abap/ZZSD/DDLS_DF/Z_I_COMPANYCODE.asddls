@EndUserText.label: 'Remote Company Code Fact Sheet'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_COMPANY_CODES'

/* Standard Header Info for the Object Page title */
@UI.headerInfo: { 
    typeName: 'Company Code', 
    typeNamePlural: 'Company Codes', 
    title: { type: #STANDARD, value: 'CompanyCode' },
    description: { type: #STANDARD, value: 'CompanyName' } 
}

define custom entity Z_I_CompanyCode
{
  /* 1. Define the Sections (Facets) on the page */
  @UI.facet: [
      { id:              'GeneralInfo',  
        type:            #COLLECTION,    
        label:           'General Configuration', 
        position:        10 },
        
      { id:              'BasicData',    
        type:            #FIELDGROUP_REFERENCE, 
        label:           'Technical Details', 
        parentId:        'GeneralInfo', 
        targetQualifier: 'Details', 
        position:        10 }
  ]

  /* 2. Field Definitions with UI Assignments */
  @UI: { lineItem:       [{ position: 10 }], 
         identification: [{ position: 10 }] }
  key CompanyCode   : abap.char(4);

  @UI: { lineItem:       [{ position: 20 }], 
         identification: [{ position: 20 }] }
  CompanyName       : abap.char(25);

  @UI: { fieldGroup:     [{ qualifier: 'Details', position: 10, label: 'City' }] }
  City              : abap.char(25);
  
  @UI: { fieldGroup:     [{ qualifier: 'Details', position: 20, label: 'Country' }] }
  Country           : abap.char(3);

  @UI: { fieldGroup:     [{ qualifier: 'Details', position: 30, label: 'Currency' }] }
  Currency          : abap.cuky;

  @UI: { fieldGroup:     [{ qualifier: 'Details', position: 40, label: 'Chart of Accounts' }] }
  ChartOfAccts      : abap.char(4);

  @UI: { fieldGroup:     [{ qualifier: 'Details', position: 50, label: 'Fiscal Year Variant' }] }
  FiscalYearVar     : abap.char(2);
  
  @UI: { fieldGroup:     [{ qualifier: 'Details', position: 60, label: 'Company' }] }
  Company           : abap.char(6);
  
  @UI: { fieldGroup:     [{ qualifier: 'Details', position: 70, label: 'Post Period Var' }] }
  PostPeriodVar     : abap.char(4);

  @UI: { fieldGroup:     [{ qualifier: 'Details', position: 80, label: 'VAT Reg No' }] }
  VatRegNo          : abap.char(20);
}
