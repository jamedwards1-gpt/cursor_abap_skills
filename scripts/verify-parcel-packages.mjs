/**
 * Read ADT metadata for key ZPARCEL objects and print their package + catalog version.
 * Use to confirm nothing important still sits in $TMP (local) instead of ZPARCEL.
 *
 *   npm run btp:verify-parcel-packages
 *
 * Optional: BTP_ADT_TRANSPORT + BTP_ADT_TRANSPORT_OWNER (+ BTP_ADT_TASK) to also print
 * the modifiable task that push scripts would use.
 */
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';
import { resolveTransportTask } from './lib/adt-transport.mjs';

const require = createRequire(import.meta.url);
const { makeAdtRequestWithAcceptNegotiation } = require(
  path.join(path.dirname(fileURLToPath(import.meta.url)), '../node_modules/@mcp-abap-adt/adt-clients/dist/utils/acceptNegotiation.js'),
);

const noopLogger = { debug: () => {}, info: () => {}, warn: () => {}, error: () => {} };

function extractPackage(xml) {
  const s = String(xml);
  const m =
    s.match(/adtcore:packageRef[^>]*adtcore:name="([^"]+)"/i) ||
    s.match(/<adtcore:packageRef[^>]+name="([^"]+)"/i);
  return m?.[1] || null;
}

function extractVersion(xml) {
  const m = String(xml).match(/adtcore:version="([^"]+)"/i);
  return m?.[1] || null;
}

async function getText(connection, url, accept) {
  const res = await makeAdtRequestWithAcceptNegotiation(
    connection,
    { method: 'GET', url, headers: { Accept: accept } },
    { logger: noopLogger },
  );
  return String(res.data);
}

const session = await connectAdtSession(loadAdtSession());
const { connection } = session;

const expected = (process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase();
console.log(`Expected package for repo pushes: ${expected}`);
console.log('');

const rows = [
  {
    label: 'Class ZCL_PARCEL_QAD_POLL',
    url: '/sap/bc/adt/oo/classes/zcl_parcel_qad_poll',
    accept: 'application/vnd.sap.adt.oo.v2+xml, application/xml, */*',
  },
  {
    label: 'Class ZCL_PARCEL_QAD_SCHEDULE',
    url: '/sap/bc/adt/oo/classes/zcl_parcel_qad_schedule',
    accept: 'application/vnd.sap.adt.oo.v2+xml, application/xml, */*',
  },
  {
    label: 'Job template ZJT_PARCEL_QAD',
    url: '/sap/bc/adt/applicationjob/templates/zjt_parcel_qad',
    accept: 'application/vnd.sap.adt.blues.v2+xml, application/xml, */*',
  },
  {
    label: 'Job catalog Z_PARCEL_QAD_BG',
    url: '/sap/bc/adt/applicationjob/catalogs/z_parcel_qad_bg',
    accept: 'application/vnd.sap.adt.blues.v2+xml, application/xml, */*',
  },
];

for (const row of rows) {
  try {
    const body = await getText(connection, row.url, row.accept);
    const pkg = extractPackage(body);
    const ver = extractVersion(body);
    const pkgLine = pkg ? `package=${pkg}` : 'package=(not in GET payload)';
    const verLine = ver ? `version=${ver}` : '';
    const warn =
      pkg && pkg.toUpperCase() === '$TMP'
        ? '  WARNING: object is in $TMP — not transportable; move to ZPARCEL in ADT or recreate via npm push scripts.'
        : pkg && pkg.toUpperCase() !== expected
          ? `  NOTE: package is ${pkg}, not ${expected}.`
          : '';
    console.log(`${row.label}: ${pkgLine}${verLine ? `, ${verLine}` : ''}${warn}`);
  } catch (e) {
    const st = e.response?.status;
    console.log(`${row.label}: GET failed (${st || 'no status'})`);
  }
}

const transport = process.env.BTP_ADT_TRANSPORT;
if (transport) {
  const owner = resolveTransportOwner(session.env);
  if (!owner) {
    console.log('\nSet BTP_ADT_TRANSPORT_OWNER to show corrNr for this transport.');
  } else {
    try {
      const resolved = await resolveTransportTask(connection, {
        transportNumber: transport,
        owner,
        taskNumber: process.env.BTP_ADT_TASK || '',
      });
      console.log(
        `\nTransport ${transport}: would use task (corrNr) ${resolved.taskNumber} for owner ${owner}.`,
      );
    } catch (e) {
      console.log(`\nCould not resolve task on ${transport}: ${e.message || e}`);
    }
  }
} else {
  console.log('\nTip: set BTP_ADT_TRANSPORT to also print the modifiable corrNr for pushes.');
}
