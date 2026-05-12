import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';
import { resolveTransportTask } from './lib/adt-transport.mjs';

const packageName = (process.argv[2] || 'ZPARCEL').toUpperCase();
const transportRequest = process.argv[3] || process.env.BTP_ADT_TRANSPORT || '';
const description = process.argv[4] || 'Parcel QAD integration and polling';
const taskNumber = process.env.BTP_ADT_TASK || '';

if (!transportRequest) {
  console.error('Usage: node scripts/create-abap-package.mjs <PACKAGE> <TRANSPORT_REQUEST> [DESCRIPTION]');
  process.exit(1);
}

const session = await connectAdtSession(loadAdtSession());
const client = new AdtClient(session.connection);
const responsible = resolveTransportOwner(session.env);
const resolved = await resolveTransportTask(session.connection, {
  transportNumber: transportRequest,
  owner: responsible,
  taskNumber,
});
const corrNr = resolved.taskNumber;

if (!responsible) {
  console.error('Responsible person is required. Set BTP_ADT_TRANSPORT_OWNER before creating a package.');
  process.exit(1);
}

try {
  await client.getPackage().readMetadata({ packageName });
  console.log(`Package ${packageName} already exists.`);
  process.exit(0);
} catch {
  // Package does not exist yet.
}

await client.getPackage().create({
  packageName,
  superPackage: 'ZLOCAL',
  description,
  packageType: 'development',
  softwareComponent: 'ZLOCAL',
  transportRequest: corrNr,
  responsible,
  recordChanges: false,
});

console.log(`Created package ${packageName} on task ${corrNr}.`);
