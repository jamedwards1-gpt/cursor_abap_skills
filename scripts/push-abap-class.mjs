import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession } from './lib/adt-session.mjs';
import { resolveTransportTask } from './lib/adt-transport.mjs';
import { lockClassForTransport } from './lib/adt-class-lock.mjs';

const require = createRequire(import.meta.url);
const adtClassRoot = path.resolve('node_modules/@mcp-abap-adt/adt-clients/dist/core/class');
const { unlockClass } = require(path.join(adtClassRoot, 'unlock.js'));
const { updateClassWithCheck } = require(path.join(adtClassRoot, 'update.js'));
const { activateClass } = require(path.join(adtClassRoot, 'activation.js'));

function parseArgs(argv) {
  const positional = [];
  const options = {
    transport: process.env.BTP_ADT_TRANSPORT || '',
    task: process.env.BTP_ADT_TASK || '',
    owner: process.env.BTP_ADT_TRANSPORT_OWNER || '',
    createClass: false,
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
      'Auth and transport selection are already working; this is an object lock, not a token or transport problem.',
    ].join(' ');
  }

  return summary || body;
}

const { positional, options } = parseArgs(process.argv.slice(2));
const className = (positional[0] || '').toUpperCase();
const sourcePath = positional[1] ? path.resolve(positional[1]) : null;

if (!className || !sourcePath) {
  console.error(
    'Usage: node scripts/push-abap-class.mjs <CLASS_NAME> <SOURCE_FILE> [--transport <REQUEST>] [--task <TASK>] [--owner <SAP_USER>] [--create]',
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

let corrNr = options.task;
let lockHandle;

try {
  if (!corrNr) {
    if (!options.transport) {
      throw new Error('Provide --transport <REQUEST> or --task <TASK> for steampunk class updates.');
    }

    const transportNumber = options.transport.toUpperCase();
    const resolved = await resolveTransportTask(connection, {
      transportNumber,
      owner: options.owner,
    });

    corrNr = resolved.taskNumber;
    const owner = options.owner || resolved.transport?.owner;
    console.log(`Using modifiable task ${corrNr} on transport ${transportNumber} for ${owner}.`);
  } else {
    console.log(`Using transport task ${corrNr}.`);
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
  ({ lockHandle, corrNr } = await lockClassForTransport(connection, className, corrNr));
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
