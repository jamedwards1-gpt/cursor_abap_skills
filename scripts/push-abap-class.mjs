import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { AdtClient, getSystemInformation } from '@mcp-abap-adt/adt-clients';
import {
  connectAdtSession,
  loadAdtSession,
  normalizeTransportListStatus,
  resolveTransportListUser,
  resolveTransportOwner,
} from './lib/adt-session.mjs';
import { listOpenTransports } from './lib/adt-object-catalog.mjs';
import { resolveTransportTask, readTransport } from './lib/adt-transport.mjs';
import { lockClassForTransport } from './lib/adt-class-lock.mjs';

const require = createRequire(import.meta.url);
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const adtClassRoot = path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/core/class');
const { unlockClass } = require(path.join(adtClassRoot, 'unlock.js'));
const { updateClassWithCheck } = require(path.join(adtClassRoot, 'update.js'));
const { activateClass } = require(path.join(adtClassRoot, 'activation.js'));
const { deleteClass } = require(path.join(adtClassRoot, 'delete.js'));

function parseArgs(argv) {
  const positional = [];
  const options = {
    transport: process.env.BTP_ADT_TRANSPORT || '',
    task: process.env.BTP_ADT_TASK || '',
    owner: process.env.BTP_ADT_TRANSPORT_OWNER || '',
    createClass: false,
    recreate: false,
    autoTransport: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--transport') {
      options.transport = argv[index + 1] || '';
      index += 1;
      continue;
    }
    if (arg === '--task') {
      options.task = argv[index + 1] || '';
      index += 1;
      continue;
    }
    if (arg === '--owner') {
      options.owner = argv[index + 1] || '';
      index += 1;
      continue;
    }
    if (arg === '--create') {
      options.createClass = true;
      continue;
    }
    if (arg === '--recreate') {
      options.recreate = true;
      options.createClass = true;
      continue;
    }
    if (arg === '--auto-transport') {
      options.autoTransport = true;
      continue;
    }
    positional.push(arg);
  }

  return { positional, options };
}

function formatAdtError(error) {
  const responseBody = error?.response?.data;
  const body = responseBody
    ? (typeof responseBody === 'string' ? responseBody : responseBody.toString())
    : (error.message || String(error));

  const localizedMessage = body.match(/<localizedMessage lang="EN">([^<]+)/)?.[1];
  const message = body.match(/<message lang="EN">([^<]+)/)?.[1];
  const summary = localizedMessage || message;

  if (summary?.includes('is currently editing')) {
    const classMatch = summary.match(/editing\s+(\S+)/i);
    const userMatch = summary.match(/User\s+(\S+)\s+is currently editing/i);
    const className = classMatch?.[1] || 'the object';
    const userName = userMatch?.[1] || 'your SAP user';

    return [
      `SAP reports an active edit lock on ${className} for ${userName} (EU510).`,
      'Close the class in ABAP Development Tools or the browser editor, or release the lock from Transport Organizer, then retry the push.',
      'If this happens right after --recreate, wait a few seconds and retry once; the script rotates the ADT session after delete, but another editor tab can still hold the lock.',
      'Auth and transport selection are already working; this is an object lock, not a token or transport problem.',
    ].join(' ');
  }

  return summary || body;
}

/** New sap-adt-connection-id + CSRF after delete reduces EU510 from stale ADT session. */
async function refreshAdtConnection(connection) {
  connection.setSessionType('stateless');
  if (typeof connection.reset === 'function') {
    connection.reset();
  }
  if (typeof connection.setSessionId === 'function') {
    connection.setSessionId(randomUUID());
  }
  if (typeof connection.connect === 'function') {
    await connection.connect();
  }
}

async function classMetadataExists(adtClient, name) {
  try {
    await adtClient.getClass().readMetadata({ className: name });
    return true;
  } catch {
    return false;
  }
}

/** True if metadata GET stops succeeding within timeout (object gone for ADT). */
async function waitUntilClassMissingSoft(adtClient, className, timeoutMs) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (!(await classMetadataExists(adtClient, className))) {
      return true;
    }
    await new Promise((r) => {
      setTimeout(r, 500);
    });
  }
  return !(await classMetadataExists(adtClient, className));
}

/**
 * Use CTS inbox (same source as transport-ui) to find a request with a modifiable task for this user.
 */
async function pickModifiableTransportNumber(connection, env, ownerCli) {
  let { user, source } = resolveTransportListUser('', env);
  if (!user) {
    const sys = await getSystemInformation(connection);
    const fromSys = String(sys?.userName || '').trim();
    if (fromSys) {
      user = fromSys;
      source = 'adt_systeminformation';
    }
  }
  if (!user) {
    throw new Error(
      'Cannot pick a transport: no SAP user for the inbox. Set SAP_USERNAME or BTP_ADT_TRANSPORT_OWNER in .secrets/btp-abap.env, or ensure ADT systeminformation returns userName.',
    );
  }

  const ownerForTask = (
    ownerCli ||
    process.env.BTP_ADT_TRANSPORT_OWNER ||
    env?.BTP_ADT_TRANSPORT_OWNER ||
    resolveTransportOwner(env) ||
    ''
  ).trim() || undefined;

  const statusPrimary = normalizeTransportListStatus(process.env.BTP_ADT_LIST_STATUS || 'D');
  let inbox = await listOpenTransports(connection, { user, status: statusPrimary });
  if (inbox.error) {
    throw new Error(`Transport list failed: ${inbox.error}`);
  }

  let candidates = (inbox.rows || []).filter((r) => r?.number).slice(0, 50);
  if (!candidates.length && statusPrimary) {
    inbox = await listOpenTransports(connection, { user, status: undefined });
    if (!inbox.error) {
      candidates = (inbox.rows || []).filter((r) => r?.number).slice(0, 50);
    }
  }

  if (!candidates.length) {
    const owner = (ownerForTask || user || '').trim();
    if (!owner) {
      throw new Error('Cannot create transport: no SAP owner resolved.');
    }
    console.warn(
      `--auto-transport: CTS inbox has no requests (${inbox.rawBytes} bytes from ADT). Creating Workbench request for ${owner}...`,
    );
    const client = new AdtClient(connection);
    const state = await client.getRequest().create({
      description: process.env.BTP_ADT_AUTO_TR_DESC || 'Cursor ADT push (auto transport)',
      transportType: 'workbench',
      owner,
    });
    const transportNumber = String(
      state.transportNumber
        || state.createResult?.data?.transport_request
        || state.createResult?.data?.transport_number
        || '',
    )
      .trim()
      .toUpperCase();
    if (!transportNumber) {
      throw new Error(
        'Workbench transport create did not return a request number. Create a request in ADT and set BTP_ADT_TRANSPORT.',
      );
    }
    console.log(`--auto-transport: created Workbench request ${transportNumber} for ${owner}.`);
    return transportNumber;
  }

  for (const row of candidates) {
    try {
      const resolved = await resolveTransportTask(connection, {
        transportNumber: row.number,
        owner: ownerForTask,
      });
      console.log(
        `--auto-transport: using request ${row.number} (task ${resolved.taskNumber}; inbox user ${user} from ${source}).`,
      );
      return String(row.number).toUpperCase();
    } catch {
      // try next request
    }
  }

  throw new Error(
    `No modifiable transport task found after checking ${candidates.length} inbox request(s). `
      + 'Add a task in ADT Transport Organizer or set BTP_ADT_TRANSPORT explicitly.',
  );
}

const { positional, options } = parseArgs(process.argv.slice(2));
const className = (positional[0] || '').toUpperCase();
const sourcePath = positional[1] ? path.resolve(positional[1]) : null;

if (!className || !sourcePath) {
  console.error(
    'Usage: node scripts/push-abap-class.mjs <CLASS_NAME> <SOURCE_FILE> [--transport <REQUEST>] [--task <TASK>] [--owner <SAP_USER>] [--create] [--recreate] [--auto-transport]',
  );
  console.error(
    '  --recreate  Delete the class as a local object (no TR), then --create on your corrNr (fixes "Local object is edited without a request" in Transport Organizer).',
  );
  console.error(
    '  --auto-transport  Pick the first CTS inbox request that has a modifiable task (no BTP_ADT_TRANSPORT). Needs SAP_USERNAME / BTP_ADT_TRANSPORT_OWNER when the JWT user is not a CB… id.',
  );
  process.exit(1);
}

if (!fs.existsSync(sourcePath)) {
  console.error(`Source file not found: ${sourcePath}`);
  process.exit(1);
}

const sourceCode = fs.readFileSync(sourcePath, 'utf8');
const session = await connectAdtSession(loadAdtSession());
const connection = session.connection;
const adtClient = new AdtClient(connection);
const packageName = (process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase();

if (options.autoTransport && !options.task && !options.transport) {
  options.transport = await pickModifiableTransportNumber(connection, session.env, options.owner);
}

let corrNr = options.task;
let lockHandle;
let transportRequestNumber;

try {
  if (!corrNr) {
    if (!options.transport) {
      throw new Error(
        'Provide --transport <REQUEST>, --task <TASK>, or --auto-transport for steampunk class updates.',
      );
    }

    const transportNumber = options.transport.toUpperCase();
    const resolved = await resolveTransportTask(connection, {
      transportNumber,
      owner: options.owner,
    });

    corrNr = resolved.taskNumber;
    transportRequestNumber = resolved.transport?.number || transportNumber;
    const owner = options.owner || resolved.transport?.owner;
    console.log(`Using modifiable task ${corrNr} on transport ${transportNumber} for ${owner}.`);
  } else {
    console.log(`Using transport task ${corrNr}.`);
    transportRequestNumber = options.transport
      ? options.transport.toUpperCase()
      : (await readTransport(connection, corrNr)).number;
  }

  if (options.recreate) {
    let classExists = false;
    try {
      await adtClient.getClass().readMetadata({ className });
      classExists = true;
    } catch {
      classExists = false;
    }
    if (classExists) {
      console.warn(
        `[recreate] Deleting ${className} so it can be re-created on transport task ${corrNr} (tries local delete first).`,
      );
      const attempts = [
        { label: 'local (no TR)', transport_request: '' },
        { label: `task ${corrNr}`, transport_request: corrNr },
        { label: `request ${transportRequestNumber}`, transport_request: transportRequestNumber },
      ];
      let anyDeleteOk = false;
      let gone = false;
      for (const a of attempts) {
        try {
          await deleteClass(connection, { class_name: className, transport_request: a.transport_request });
          console.warn(`[recreate] Delete via ${a.label} OK.`);
          anyDeleteOk = true;
          await refreshAdtConnection(connection);
          gone = await waitUntilClassMissingSoft(adtClient, className, 12000);
          if (gone) {
            console.warn(`[recreate] ${className} no longer visible to ADT after ${a.label}.`);
            await refreshAdtConnection(connection);
            break;
          }
          console.warn(
            `[recreate] ${className} still visible after ${a.label}; trying next delete variant if any.`,
          );
        } catch (e) {
          const msg = String(e?.response?.data || e?.message || e);
          console.warn(`[recreate] Delete ${a.label} failed: ${msg.slice(0, 200)}`);
        }
      }
      if (!anyDeleteOk) {
        throw new Error(
          `[recreate] Could not delete ${className}. Close it in ADT, or delete manually, then retry without --recreate if the object is already gone.`,
        );
      }
      if (!gone) {
        throw new Error(
          `[recreate] ${className} still visible after local/task/request deletes (metadata GET still succeeds). Remove the object in ADT or SE80, then retry.`,
        );
      }
    }
  }

  if (options.createClass) {
    let classExists = false;
    try {
      await adtClient.getClass().readMetadata({ className });
      classExists = true;
    } catch {
      classExists = false;
    }

    if (!classExists) {
      await adtClient.getClass().create(
        {
          className,
          packageName,
          transportRequest: corrNr,
          sourceCode,
        },
        {
          sourceCode,
        },
      );
      console.log(`Created class shell ${className} on task ${corrNr}.`);
    }
  }

  connection.setSessionType('stateful');
  ({ lockHandle, corrNr } = await lockClassForTransport(connection, className, corrNr, {
    transportRequestNumber,
  }));
  await updateClassWithCheck(connection, className, sourceCode, lockHandle, corrNr);
  await unlockClass(connection, className, lockHandle);
  lockHandle = undefined;
  connection.setSessionType('stateless');
  await activateClass(connection, className);
  console.log(`Updated and activated ${className} on task ${corrNr} from ${sourcePath}`);
} catch (error) {
  if (lockHandle) {
    try {
      connection.setSessionType('stateful');
      await unlockClass(connection, className, lockHandle);
      connection.setSessionType('stateless');
    } catch {
      // Best-effort unlock after a failed update.
    }
  }

  console.error(formatAdtError(error));
  process.exit(1);
}
