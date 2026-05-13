import { AdtClient, getSystemInformation } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';
import { pickModifiableTransportNumber } from './lib/adt-auto-transport.mjs';
import { resolveTransportTask } from './lib/adt-transport.mjs';

function parseArgs(argv) {
  const flags = {
    autoTransport: false,
    /** When false, matches ADT "Record objects changes in transport requests" unchecked. */
    recordChanges: true,
    superPackage: 'ZLOCAL',
    softwareComponent: 'ZLOCAL',
    transportLayer: '',
    /** If true, do not retry with recordChanges=false when SAP returns TR434. */
    strictRecordChanges: false,
  };
  const positional = [];

  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--auto-transport') {
      flags.autoTransport = true;
      continue;
    }
    if (a === '--no-record-changes') {
      flags.recordChanges = false;
      continue;
    }
    if (a === '--strict-record-changes') {
      flags.strictRecordChanges = true;
      continue;
    }
    if (a === '--super-package' && argv[i + 1]) {
      flags.superPackage = String(argv[i + 1]).trim().toUpperCase();
      i += 1;
      continue;
    }
    if (a === '--software-component' && argv[i + 1]) {
      flags.softwareComponent = String(argv[i + 1]).trim().toUpperCase();
      i += 1;
      continue;
    }
    if (a === '--transport-layer' && argv[i + 1]) {
      flags.transportLayer = String(argv[i + 1]).trim().toUpperCase();
      i += 1;
      continue;
    }
    positional.push(a);
  }

  const packageName = (positional[0] || '').toUpperCase();
  let transportRequest = process.env.BTP_ADT_TRANSPORT || '';
  let description = 'Development package (transport-tracked by default)';

  if (flags.autoTransport) {
    description = positional.slice(1).join(' ').trim() || description;
  } else {
    const tr = (positional[1] || '').trim();
    if (tr && !tr.startsWith('-')) {
      transportRequest = tr.toUpperCase();
    }
    description = positional.slice(2).join(' ').trim() || description;
  }

  return {
    packageName,
    transportRequest,
    description,
    flags,
  };
}

const { packageName, transportRequest: trFromArgs, description, flags } = parseArgs(process.argv.slice(2));

if (!packageName) {
  console.error(
    [
      'Usage:',
      '  node scripts/create-abap-package.mjs <PACKAGE> <TRANSPORT_REQUEST> [DESCRIPTION] [--no-record-changes]',
      '  node scripts/create-abap-package.mjs <PACKAGE> --auto-transport [DESCRIPTION] [--no-record-changes]',
      '',
      'Creates a subpackage of --super-package (default ZLOCAL). By default the script requests',
      'pak:recordChanges=true (ADT “Record objects changes in transport requests”).',
      'On some BTP systems SAP returns TR434 for API-created packages under ZLOCAL; then this',
      'script retries with recordChanges=false unless you pass --strict-record-changes.',
      'If that happens, open the package in ADT → Overview and turn recording on if editable.',
      '',
      'Options:',
      '  --auto-transport             Pick or create a modifiable Workbench request.',
      '  --no-record-changes          Force pak:recordChanges=false.',
      '  --strict-record-changes      Fail on TR434 instead of retrying without recording.',
      '  --super-package <NAME>       Default ZLOCAL (use e.g. ZZSD if you keep app objects there).',
      '  --software-component <C>     Default ZLOCAL.',
      '  --transport-layer <L>        Optional; also BTP_ADT_TRANSPORT_LAYER. SGIT needs matching transport target.',
    ].join('\n'),
  );
  process.exit(1);
}

const session = await connectAdtSession(loadAdtSession());
const client = new AdtClient(session.connection);
let responsible = resolveTransportOwner(session.env);
if (!responsible) {
  const sys = await getSystemInformation(session.connection);
  responsible = String(sys?.userName || '').trim();
}
const taskNumber = process.env.BTP_ADT_TASK || '';

if (!responsible) {
  console.error('Responsible person is required. Set SAP_USERNAME or BTP_ADT_TRANSPORT_OWNER in .secrets/btp-abap.env.');
  process.exit(1);
}

let transportRequest = trFromArgs;
if (flags.autoTransport) {
  transportRequest = await pickModifiableTransportNumber(session.connection, session.env, '');
} else if (!transportRequest) {
  console.error('Provide <TRANSPORT_REQUEST> or use --auto-transport (or set BTP_ADT_TRANSPORT).');
  process.exit(1);
}

const resolved = await resolveTransportTask(session.connection, {
  transportNumber: transportRequest,
  owner: responsible,
  taskNumber,
});
const corrNr = resolved.taskNumber;

try {
  await client.getPackage().readMetadata({ packageName });
  console.log(`Package ${packageName} already exists.`);
  process.exit(0);
} catch {
  // Package does not exist yet.
}

const transportLayerResolved =
  flags.transportLayer ||
  process.env.BTP_ADT_TRANSPORT_LAYER?.trim() ||
  undefined;

function isTr434(body) {
  return String(body || '').includes('TR434') || String(body || '').includes('No change recording for local packages');
}

async function doCreate(wantRecord) {
  await client.getPackage().create({
    packageName,
    superPackage: flags.superPackage,
    description,
    packageType: 'development',
    softwareComponent: flags.softwareComponent,
    transportLayer: transportLayerResolved,
    transportRequest: corrNr,
    responsible,
    recordChanges: wantRecord,
  });
}

try {
  if (flags.recordChanges) {
    try {
      await doCreate(true);
      console.log(
        `Created package ${packageName} on task ${corrNr} (recordChanges=true, transportLayer=${transportLayerResolved || '(empty)'}).`,
      );
    } catch (e) {
      const body = e?.response?.data;
      const text = typeof body === 'string' ? body : String(body || '');
      if (!flags.strictRecordChanges && isTr434(text)) {
        console.warn(
          'SAP refused recordChanges=true (TR434 / local package). Retrying with recordChanges=false.',
        );
        console.warn(
          'Enable “Record objects changes in transport requests” in ADT on the package Overview if the UI allows it.',
        );
        await doCreate(false);
        console.log(`Created package ${packageName} on task ${corrNr} (recordChanges=false — adjust in ADT if needed).`);
      } else {
        throw e;
      }
    }
  } else {
    await doCreate(false);
    console.log(`Created package ${packageName} on task ${corrNr} (recordChanges=false).`);
  }
} catch (error) {
  const body = error?.response?.data;
  console.error(typeof body === 'string' ? body.slice(0, 4000) : error?.message || String(error));
  process.exit(1);
}
