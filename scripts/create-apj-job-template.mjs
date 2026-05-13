/**
 * Create or update an Application Job Template (SAJT) on SAP BTP ABAP via ADT REST.
 *
 * Binds the template to an Application Job Catalog entry (SAJC) via generalInformation.catalogName.
 *
 * Prerequisites: npm run btp:auth, BTP_ADT_TRANSPORT, BTP_ADT_TASK, BTP_ADT_TRANSPORT_OWNER.
 * Create the catalog entry first (npm run btp:create-apj-catalog).
 *
 * Usage:
 *   node scripts/create-apj-job-template.mjs
 *   node scripts/create-apj-job-template.mjs --template ZJT_PARCEL_QAD --catalog Z_PARCEL_QAD_BG --package ZPARCEL
 */
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { XMLParser } from 'fast-xml-parser';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';
import { resolveTransportTask } from './lib/adt-transport.mjs';

const require = createRequire(import.meta.url);
const { makeAdtRequestWithAcceptNegotiation } = require(
  path.join(path.dirname(fileURLToPath(import.meta.url)), '../node_modules/@mcp-abap-adt/adt-clients/dist/utils/acceptNegotiation.js'),
);
const { ACCEPT_LOCK } = require(
  path.join(path.dirname(fileURLToPath(import.meta.url)), '../node_modules/@mcp-abap-adt/adt-clients/dist/constants/contentTypes.js'),
);

const noopLogger = { debug: () => {}, info: () => {}, warn: () => {}, error: () => {} };

function parseArgs(argv) {
  const out = {
    templateName: 'ZJT_PARCEL_QAD',
    catalogName: 'Z_PARCEL_QAD_BG',
    packageName: (process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase(),
    description: 'Parcel QAD — poll & discover',
    pBatch: '5',
    pClient: 'UK1',
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--template' && argv[i + 1]) {
      out.templateName = argv[i + 1].toUpperCase();
      i += 1;
    } else if (a === '--catalog' && argv[i + 1]) {
      out.catalogName = argv[i + 1].toUpperCase();
      i += 1;
    } else if (a === '--package' && argv[i + 1]) {
      out.packageName = argv[i + 1].toUpperCase();
      i += 1;
    } else if (a === '--description' && argv[i + 1]) {
      out.description = argv[i + 1];
      i += 1;
    } else if (a === '--p-batch' && argv[i + 1]) {
      out.pBatch = argv[i + 1];
      i += 1;
    } else if (a === '--p-client' && argv[i + 1]) {
      out.pClient = argv[i + 1];
      i += 1;
    }
  }
  return out;
}

function escapeXmlAttr(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function objectPathLower(name) {
  return name.trim().toLowerCase();
}

async function templateExists(connection, lowerName) {
  try {
    await makeAdtRequestWithAcceptNegotiation(
      connection,
      {
        method: 'GET',
        url: `/sap/bc/adt/applicationjob/templates/${lowerName}`,
        headers: { Accept: 'application/vnd.sap.adt.blues.v2+xml, application/xml, */*' },
      },
      { logger: noopLogger },
    );
    return true;
  } catch (e) {
    if (e.response?.status === 404) {
      return false;
    }
    throw e;
  }
}

async function createTemplateShell(connection, { templateName, description, packageName, corrNr, owner }) {
  const lower = objectPathLower(templateName);
  const rel = encodeURIComponent(`/sap/bc/adt/packages/${packageName}`);
  const url = `/sap/bc/adt/applicationjob/templates?corrNr=${encodeURIComponent(corrNr)}&relatedObjectUri=${rel}`;
  const pkgLower = packageName.toLowerCase();
  const xml =
    '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<blue:blueSource xmlns:blue="http://www.sap.com/wbobj/blue" ' +
    'xmlns:adtcore="http://www.sap.com/adt/core" xmlns:abapsource="http://www.sap.com/adt/abapsource" ' +
    `adtcore:name="${escapeXmlAttr(templateName)}" adtcore:type="SAJT" adtcore:description="${escapeXmlAttr(description)}" adtcore:masterLanguage="EN" ` +
    'adtcore:abapLanguageVersion="cloudDevelopment" ' +
    `adtcore:responsible="${escapeXmlAttr(owner)}" ` +
    `abapsource:sourceUri="./${lower}/source/main">` +
    `<adtcore:packageRef adtcore:uri="/sap/bc/adt/packages/${pkgLower}" adtcore:type="DEVC/K" ` +
    `adtcore:name="${escapeXmlAttr(packageName)}" adtcore:description="${escapeXmlAttr('Development package')}"/>` +
    '</blue:blueSource>';

  return makeAdtRequestWithAcceptNegotiation(
    connection,
    {
      method: 'POST',
      url,
      data: xml,
      headers: {
        'Content-Type': 'application/vnd.sap.adt.blues.v2+xml',
        Accept: 'application/vnd.sap.adt.blues.v2+xml, */*',
        Slug: templateName,
      },
    },
    { logger: noopLogger },
  );
}

async function writeTemplateSource(connection, { templateName, catalogName, description, pBatch, pClient, corrNr }) {
  const lower = objectPathLower(templateName);
  const base = `/sap/bc/adt/applicationjob/templates/${lower}/source/main`;
  const jsonBody = JSON.stringify({
    formatVersion: '1',
    header: {
      description,
      originalLanguage: 'en',
      abapLanguageVersion: 'cloudDevelopment',
    },
    generalInformation: {
      catalogName: catalogName,
    },
    parameters: {
      singleValueParameters: [
        { name: 'P_BATCH', value: String(pBatch) },
        { name: 'P_CLIENT', value: String(pClient) },
      ],
    },
  });

  connection.setSessionType('stateful');
  const lockUrl = `${base}?_action=LOCK&accessMode=MODIFY&corrNr=${encodeURIComponent(corrNr)}&version=inactive`;
  let lockHandle;
  try {
    const lockRes = await makeAdtRequestWithAcceptNegotiation(
      connection,
      { method: 'POST', url: lockUrl, data: null, headers: { Accept: ACCEPT_LOCK } },
      { logger: noopLogger },
    );
    const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '' });
    lockHandle = parser.parse(lockRes.data)?.['asx:abap']?.['asx:values']?.DATA?.LOCK_HANDLE;
  } catch (e) {
    connection.setSessionType('stateless');
    const body = String(e.response?.data || '');
    if (e.response?.status === 403 && (body.includes('EU510') || body.includes('currently editing'))) {
      throw new Error(
        `Cannot lock ${templateName} for update (EU510). Close the job template in ADT, then re-run: npm run btp:create-apj-job-template`,
      );
    }
    throw e;
  }

  if (!lockHandle) {
    connection.setSessionType('stateless');
    throw new Error('ADT lock did not return LOCK_HANDLE.');
  }

  try {
    const putUrl = `${base}?lockHandle=${encodeURIComponent(lockHandle)}&corrNr=${encodeURIComponent(corrNr)}&version=inactive`;
    await makeAdtRequestWithAcceptNegotiation(
      connection,
      {
        method: 'PUT',
        url: putUrl,
        data: jsonBody,
        headers: { 'Content-Type': 'application/json', Accept: 'application/json, */*' },
      },
      { logger: noopLogger },
    );
  } finally {
    try {
      await connection.makeAdtRequest({
        method: 'POST',
        url: `${base}?_action=UNLOCK&lockHandle=${encodeURIComponent(lockHandle)}&version=inactive`,
        data: null,
      });
    } catch {
      // Best-effort unlock.
    }
    connection.setSessionType('stateless');
  }
}

async function tryActivate(connection, templateName) {
  const lower = objectPathLower(templateName);
  const actXml =
    '<?xml version="1.0" encoding="UTF-8"?><adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">' +
    `<adtcore:objectReference adtcore:uri="/sap/bc/adt/applicationjob/templates/${lower}" adtcore:type="SAJT" adtcore:name="${escapeXmlAttr(templateName)}"/>` +
    '</adtcore:objectReferences>';
  const start = await makeAdtRequestWithAcceptNegotiation(
    connection,
    {
      method: 'POST',
      url: '/sap/bc/adt/activation/runs?method=activate&preauditRequested=false',
      data: actXml,
      headers: { 'Content-Type': 'application/xml', Accept: 'application/xml' },
    },
    { logger: noopLogger },
  );
  const loc = start.headers?.location || start.headers?.Location;
  const runId = loc ? String(loc).match(/\/runs\/([^/?]+)/)?.[1] : null;
  if (!runId) {
    console.warn('Activation started but no run id in Location header; activate manually in ADT.');
    return;
  }
  const statusRes = await makeAdtRequestWithAcceptNegotiation(
    connection,
    {
      method: 'GET',
      url: `/sap/bc/adt/activation/runs/${runId}?withLongPolling=true`,
      headers: { Accept: 'application/xml, application/vnd.sap.adt.backgroundrun.v1+xml' },
    },
    { logger: noopLogger },
  );
  const xml = String(statusRes.data);
  if (xml.includes('runs:status="finished"')) {
    console.log(`Activation run finished for ${templateName}.`);
    return;
  }
  if (xml.includes('EU510') || xml.includes('currently editing')) {
    console.warn(
      `Activation did not complete (EU510). Close ${templateName} in ADT, then Activate from the context menu.`,
    );
    return;
  }
  console.warn('Activation run ended with an unexpected status; check ADT.');
  console.warn(xml.slice(0, 600));
}

const opts = parseArgs(process.argv.slice(2));
const transport = process.env.BTP_ADT_TRANSPORT;
if (!transport) {
  console.error('Set BTP_ADT_TRANSPORT (and BTP_ADT_TASK) before running this script.');
  process.exit(1);
}

const session = await connectAdtSession(loadAdtSession());
const { connection } = session;
const owner = resolveTransportOwner(session.env);
if (!owner) {
  console.error('Set BTP_ADT_TRANSPORT_OWNER to your ABAP user (e.g. CB9980000010).');
  process.exit(1);
}

try {
  const resolved = await resolveTransportTask(connection, {
    transportNumber: transport,
    owner,
    taskNumber: process.env.BTP_ADT_TASK || '',
  });
  const corrNr = resolved.taskNumber;
  const lower = objectPathLower(opts.templateName);

  const exists = await templateExists(connection, lower);
  if (!exists) {
    const created = await createTemplateShell(connection, {
      templateName: opts.templateName,
      description: opts.description,
      packageName: opts.packageName,
      corrNr,
      owner,
    });
    console.log(`Created job template shell ${opts.templateName} (${created.status}).`);
  } else {
    console.log(`Job template ${opts.templateName} already exists; updating source only.`);
  }

  await writeTemplateSource(connection, {
    templateName: opts.templateName,
    catalogName: opts.catalogName,
    description: opts.description,
    pBatch: opts.pBatch,
    pClient: opts.pClient,
    corrNr,
  });
  console.log(`Wrote template source → catalog ${opts.catalogName}, P_BATCH=${opts.pBatch}, P_CLIENT=${opts.pClient}.`);

  await tryActivate(connection, opts.templateName);
} catch (error) {
  console.error(error?.message || String(error));
  process.exit(1);
}
