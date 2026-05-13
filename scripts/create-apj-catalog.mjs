/**
 * Create or update an Application Job Catalog Entry (SAJC) on SAP BTP ABAP via ADT REST.
 *
 * Prerequisites: npm run btp:auth, BTP_ADT_TRANSPORT, BTP_ADT_TASK, BTP_ADT_TRANSPORT_OWNER.
 *
 * Usage:
 *   node scripts/create-apj-catalog.mjs
 *   node scripts/create-apj-catalog.mjs --name Z_MY_JOB_CAT --handler ZCL_MY_JOB_HANDLER --package ZZSD
 *
 * After a successful run, activate the object in ADT if it is still inactive (or close the editor
 * if activation reports EU510 — the object is open in Eclipse).
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
    name: 'Z_MY_JOB_CAT',
    handler: 'ZCL_MY_JOB_HANDLER',
    packageName: (process.env.BTP_ADT_PACKAGE || 'ZZSD').toUpperCase(),
    description: 'Application job catalog (set --name / --handler for your handler class)',
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--name' && argv[i + 1]) {
      out.name = argv[i + 1].toUpperCase();
      i += 1;
    } else if (a === '--handler' && argv[i + 1]) {
      out.handler = argv[i + 1].toUpperCase();
      i += 1;
    } else if (a === '--package' && argv[i + 1]) {
      out.packageName = argv[i + 1].toUpperCase();
      i += 1;
    } else if (a === '--description' && argv[i + 1]) {
      out.description = argv[i + 1];
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

function catalogPathLower(name) {
  return name.trim().toLowerCase();
}

async function catalogExists(connection, lowerName) {
  try {
    await makeAdtRequestWithAcceptNegotiation(
      connection,
      {
        method: 'GET',
        url: `/sap/bc/adt/applicationjob/catalogs/${lowerName}`,
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

async function createCatalogShell(connection, { name, description, packageName, corrNr, owner }) {
  const lower = catalogPathLower(name);
  const rel = encodeURIComponent(`/sap/bc/adt/packages/${packageName}`);
  const url = `/sap/bc/adt/applicationjob/catalogs?corrNr=${encodeURIComponent(corrNr)}&relatedObjectUri=${rel}`;
  const pkgLower = packageName.toLowerCase();
  const xml =
    '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<blue:blueSource xmlns:blue="http://www.sap.com/wbobj/blue" ' +
    'xmlns:adtcore="http://www.sap.com/adt/core" xmlns:abapsource="http://www.sap.com/adt/abapsource" ' +
    `adtcore:name="${escapeXmlAttr(name)}" adtcore:type="SAJC" adtcore:description="${escapeXmlAttr(description)}" adtcore:masterLanguage="EN" ` +
    'adtcore:abapLanguageVersion="cloudDevelopment" ' +
    `adtcore:responsible="${escapeXmlAttr(owner)}" ` +
    `abapsource:sourceUri="./${lower}/source/main">` +
    `<adtcore:packageRef adtcore:uri="/sap/bc/adt/packages/${pkgLower}" adtcore:type="DEVC/K" ` +
    `adtcore:name="${escapeXmlAttr(packageName)}" adtcore:description="${escapeXmlAttr('Development package')}"/>` +
    '</blue:blueSource>';

  const res = await makeAdtRequestWithAcceptNegotiation(
    connection,
    {
      method: 'POST',
      url,
      data: xml,
      headers: {
        'Content-Type': 'application/vnd.sap.adt.blues.v2+xml',
        Accept: 'application/vnd.sap.adt.blues.v2+xml, */*',
        Slug: name,
      },
    },
    { logger: noopLogger },
  );
  return res;
}

async function writeCatalogSource(connection, { name, handler, description, corrNr }) {
  const lower = catalogPathLower(name);
  const base = `/sap/bc/adt/applicationjob/catalogs/${lower}/source/main`;
  const jsonBody = JSON.stringify({
    formatVersion: '1',
    header: {
      description,
      originalLanguage: 'en',
      abapLanguageVersion: 'cloudDevelopment',
    },
    generalInformation: { className: handler },
    parameters: [
      { name: 'P_BATCH', readOnly: true },
      { name: 'P_CLIENT', readOnly: true },
    ],
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
        `Cannot lock ${name} for update (EU510). Close the Application Job Catalog Entry in ADT, then re-run: npm run btp:create-apj-catalog`,
      );
    }
    throw e;
  }

  if (!lockHandle) {
    connection.setSessionType('stateless');
    throw new Error('ADT lock did not return LOCK_HANDLE. Close the catalog entry in ADT if it is open.');
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

async function tryActivate(connection, name) {
  const lower = catalogPathLower(name);
  const actXml =
    '<?xml version="1.0" encoding="UTF-8"?><adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">' +
    `<adtcore:objectReference adtcore:uri="/sap/bc/adt/applicationjob/catalogs/${lower}" adtcore:type="SAJC" adtcore:name="${escapeXmlAttr(name)}"/>` +
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
  if (xml.includes('runs:status="finished"') || xml.includes("runs:status='finished'")) {
    console.log(`Activation finished for ${name}.`);
    return;
  }
  if (xml.includes('EU510') || xml.includes('currently editing')) {
    console.warn(
      `Activation did not complete (EU510 / edit lock). Close ${name} in ADT, then activate with context menu → Activate.`,
    );
    return;
  }
  console.warn('Activation run ended with non-success status; check ADT activation log for details.');
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
  const lower = catalogPathLower(opts.name);

  const exists = await catalogExists(connection, lower);
  if (!exists) {
    const created = await createCatalogShell(connection, {
      name: opts.name,
      description: opts.description,
      packageName: opts.packageName,
      corrNr,
      owner,
    });
    console.log(`Created catalog shell ${opts.name} (${created.status}).`);
  } else {
    console.log(`Catalog ${opts.name} already exists; updating source only.`);
  }

  await writeCatalogSource(connection, {
    name: opts.name,
    handler: opts.handler,
    description: opts.description,
    corrNr,
  });
  console.log(`Wrote catalog source for handler ${opts.handler} (P_BATCH, P_CLIENT).`);

  await tryActivate(connection, opts.name);
} catch (error) {
  console.error(error?.message || String(error));
  process.exit(1);
}
