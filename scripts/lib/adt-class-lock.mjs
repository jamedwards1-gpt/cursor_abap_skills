import { createRequire } from 'node:module';
import path from 'node:path';
import { XMLParser } from 'fast-xml-parser';

const require = createRequire(import.meta.url);
const contentTypesPath = path.resolve('node_modules/@mcp-abap-adt/adt-clients/dist/constants/contentTypes.js');
const internalUtilsPath = path.resolve('node_modules/@mcp-abap-adt/adt-clients/dist/utils/internalUtils.js');
const { ACCEPT_LOCK } = require(contentTypesPath);
const { encodeSapObjectName } = require(internalUtilsPath);

const lockParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
});

export async function lockClassForTransport(connection, className, corrNr) {
  const encodedName = encodeSapObjectName(className).toLowerCase();
  const url = `/sap/bc/adt/oo/classes/${encodedName}?_action=LOCK&accessMode=MODIFY&corrNr=${encodeURIComponent(corrNr)}`;
  const response = await connection.makeAdtRequest({
    url,
    method: 'POST',
    data: null,
    headers: { Accept: ACCEPT_LOCK },
  });

  const result = lockParser.parse(response.data);
  const data = result?.['asx:abap']?.['asx:values']?.DATA;
  const lockHandle = data?.LOCK_HANDLE;
  const assignedCorrNr = data?.CORRNR;

  if (!lockHandle) {
    throw new Error(`Failed to lock ${className} on transport ${corrNr}.`);
  }

  return {
    lockHandle,
    corrNr: assignedCorrNr || corrNr,
  };
}
