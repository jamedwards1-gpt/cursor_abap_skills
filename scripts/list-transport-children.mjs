/**
 * ADT transport “children” / object URIs: GET `/sap/bc/adt/cts/transportrequests/<TR>`.
 * On-prem Eclipse may use `transportorganizertree.v1+xml`; **ABAP Environment (Steampunk)** returns 406
 * for that Accept and only allows `transportorganizer.v1+xml` — we fall back automatically.
 *
 * Usage:
 *   npm run btp:transport-children -- H01K900034
 *   BTP_ADT_TRANSPORT=H01K900034 node scripts/list-transport-children.mjs
 *
 * Requires: npm run btp:auth, .secrets/btp-abap.env
 */
import { getTransportOrganizerTreeXml, parseTransportAbapObjects, readTransport } from './lib/adt-transport.mjs';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';

const argv = process.argv.slice(2);
const raw = argv.includes('--raw');
const positional = argv.filter((a) => !a.startsWith('-'));

function extractUris(xml) {
  const set = new Set();
  const patterns = [
    /adtcore:uri="([^"]+)"/g,
    /adtcore:uri='([^']+)'/g,
    /href="(\/sap\/bc\/adt[^"]+)"/g,
  ];
  for (const re of patterns) {
    let match = re.exec(xml);
    while (match !== null) {
      set.add(match[1]);
      match = re.exec(xml);
    }
  }
  return [...set].sort();
}

function uniqueTmTags(xml) {
  const set = new Set();
  const re = /<(\/?)(tm:[a-zA-Z0-9_-]+)/g;
  let m = re.exec(xml);
  while (m !== null) {
    set.add(m[2]);
    m = re.exec(xml);
  }
  return [...set].sort();
}

function printTreeSection(label, transportNumber, { status, xml, flavor, message }) {
  console.log('');
  console.log(`=== ${label}: ${transportNumber} (HTTP ${status}, ${xml.length} bytes) ===`);
  if (flavor) {
    console.log(`  flavor: ${flavor}`);
  }
  if (message) {
    console.log(`  ${message}`);
  }
  if (!raw) {
    const tags = uniqueTmTags(xml);
    if (tags.length > 0) {
      console.log(`  tm:* tags in payload: ${tags.join(', ')}`);
    }
  }
  if (raw) {
    console.log(xml.slice(0, 24000));
    if (xml.length > 24000) {
      console.log(`\n… truncated (${xml.length} bytes total); omit --raw for URI list only`);
    }
    return;
  }
  const uris = extractUris(xml);
  if (uris.length === 0) {
    console.log('No adtcore:uri / sap/bc/adt href attributes found (empty tree or different XML shape).');
    console.log('First 1200 chars for inspection:');
    console.log(xml.slice(0, 1200));
  } else {
    console.log(`Found ${uris.length} URI(s):`);
    for (const u of uris) {
      console.log(`  ${u}`);
    }
  }
  const abap = parseTransportAbapObjects(xml);
  if (abap.length > 0) {
    console.log(`tm:abap_object count: ${abap.length} (first 15):`);
    for (const o of abap.slice(0, 15)) {
      console.log(`  ${o.type || '?'}\t${o.name}\t${o.uri || ''}`);
    }
  } else {
    console.log('tm:abap_object: none parsed (try --raw to inspect XML).');
  }
}

const transportNumber = (positional[0] || process.env.BTP_ADT_TRANSPORT || '').trim().toUpperCase();

if (!transportNumber) {
  console.error(
    'Usage: node scripts/list-transport-children.mjs <TRANSPORT_REQUEST> [--raw]\n'
      + 'Example: npm run btp:transport-children -- H01K900034',
  );
  process.exit(1);
}

const session = await connectAdtSession(loadAdtSession());
const { connection } = session;
const owner = resolveTransportOwner(session.env);

const meta = await readTransport(connection, transportNumber);
console.log(`Transport metadata (v1 organizer) for ${meta.number}:`);
console.log(`  owner=${meta.owner} status=${meta.status} (${meta.statusText})`);
console.log(`  description=${meta.description}`);
console.log(`  tasks=${meta.tasks.length}`);
for (const t of meta.tasks) {
  console.log(
    `    - ${t.number} owner=${t.owner} status=${t.status} (${t.statusText}) ${t.description || ''}`,
  );
}

const organizer = await getTransportOrganizerTreeXml(connection, transportNumber);
printTreeSection(
  'Transport organizer XML (tree on-prem, v1 fallback on Steampunk)',
  transportNumber,
  organizer,
);

const modifiableTasks = meta.tasks.filter((t) => t.status === 'D' && (!owner || t.owner === owner));
for (const t of modifiableTasks) {
  if (t.number.toUpperCase() === transportNumber) {
    continue;
  }
  const taskTree = await getTransportOrganizerTreeXml(connection, t.number);
  printTreeSection('Task TREE (children Accept)', t.number, taskTree);
}

console.log('');
console.log(
  'If Eclipse shows no objects but pushes succeeded, objects may not be recorded on the CTS request '
    + '(e.g. local-only lock / corrNr). Compare URI list above with SE01/Eclipse request contents.',
);
