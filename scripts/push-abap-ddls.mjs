import fs from 'node:fs';
import path from 'node:path';
import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession } from './lib/adt-session.mjs';
import { resolveTransportTask } from './lib/adt-transport.mjs';

function parseArgs(argv) {
  const positional = [];
  const options = {
    transport: process.env.BTP_ADT_TRANSPORT || '',
    task: process.env.BTP_ADT_TASK || '',
    owner: process.env.BTP_ADT_TRANSPORT_OWNER || '',
    createView: false,
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
      options.createView = true;
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
  return localizedMessage || message || body;
}

function extractDescription(ddlSource, fallback) {
  const label = ddlSource.match(/@EndUserText\.label:\s*'([^']+)'/)?.[1];
  return label || fallback;
}

const { positional, options } = parseArgs(process.argv.slice(2));
const viewName = (positional[0] || '').toUpperCase();
const sourcePath = positional[1] ? path.resolve(positional[1]) : null;

if (!viewName || !sourcePath) {
  console.error(
    'Usage: node scripts/push-abap-ddls.mjs <VIEW_NAME> <SOURCE_FILE> [--transport <REQUEST>] [--task <TASK>] [--owner <SAP_USER>] [--create]',
  );
  process.exit(1);
}

if (!fs.existsSync(sourcePath)) {
  console.error(`Source file not found: ${sourcePath}`);
  process.exit(1);
}

const ddlSource = fs.readFileSync(sourcePath, 'utf8');
const description = extractDescription(ddlSource, viewName);
const session = await connectAdtSession(loadAdtSession());
const connection = session.connection;
const adtClient = new AdtClient(connection);
const packageName = (process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase();

let corrNr = options.task;

try {
  if (!corrNr) {
    if (!options.transport) {
      throw new Error('Provide --transport <REQUEST> or --task <TASK> for steampunk CDS view updates.');
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

  let viewExists = false;
  try {
    await adtClient.getView().readMetadata({ viewName });
    viewExists = true;
  } catch {
    viewExists = false;
  }

  if (!viewExists) {
    await adtClient.getView().create(
      {
        viewName,
        packageName,
        transportRequest: corrNr,
        description,
      },
      {
        sourceCode: ddlSource,
      },
    );
    console.log(`Created CDS view shell ${viewName} on task ${corrNr}.`);
  }

  await adtClient.getView().update(
    {
      viewName,
      transportRequest: corrNr,
    },
    {
      sourceCode: ddlSource,
      activateOnUpdate: true,
    },
  );

  console.log(`Updated and activated ${viewName} on task ${corrNr} from ${sourcePath}`);
} catch (error) {
  console.error(formatAdtError(error));
  process.exit(1);
}
