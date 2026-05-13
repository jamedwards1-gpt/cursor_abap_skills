import { connectAdtSession, loadAdtSession } from './lib/adt-session.mjs';
import { createTransportTask, readTransport, normalizeTaskTypeForAdt } from './lib/adt-transport.mjs';

function parseArgs(argv) {
  const options = {
    transport: process.env.BTP_ADT_TRANSPORT || '',
    owner: process.env.BTP_ADT_TRANSPORT_OWNER || '',
    description: process.env.BTP_ADT_TASK_DESCRIPTION || 'Cursor ADT class update',
    /** @type {string} tm:type for the new task (Workbench is normalized to Development/Correction — see README) */
    taskType: process.env.BTP_ADT_TASK_TYPE || 'Development/Correction',
    listOnly: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--transport') {
      options.transport = argv[index + 1] || '';
      index += 1;
      continue;
    }
    if (arg === '--owner') {
      options.owner = argv[index + 1] || '';
      index += 1;
      continue;
    }
    if (arg === '--description') {
      options.description = argv[index + 1] || options.description;
      index += 1;
      continue;
    }
    if (arg === '--type') {
      options.taskType = argv[index + 1] || options.taskType;
      index += 1;
      continue;
    }
    if (arg === '--list') {
      options.listOnly = true;
    }
  }

  return options;
}

const options = parseArgs(process.argv.slice(2));
if (!options.transport) {
  console.error(
    'Usage: node scripts/create-transport-task.mjs --transport <REQUEST_OR_TASK> [--owner <SAP_USER>] [--description <TEXT>] [--type <TASK_TM_TYPE>] [--list]',
  );
  console.error(
    'Default --type is Development/Correction. Use --type Workbench as a synonym for that (Workbench is the request type K, not task tm:type in ADT).',
  );
  process.exit(1);
}

const session = await connectAdtSession(loadAdtSession());
const transportNumber = options.transport.toUpperCase();
const transport = await readTransport(session.connection, transportNumber);
const owner = options.owner || transport.owner;

if (options.listOnly) {
  console.log(`Transport ${transport.number}: ${transport.description}`);
  for (const task of transport.tasks) {
    console.log(`- ${task.number} ${task.owner} ${task.status} ${task.description}`);
  }
  process.exit(0);
}

if (!owner) {
  console.error('Transport owner is required. Pass --owner or set BTP_ADT_TRANSPORT_OWNER.');
  process.exit(1);
}

if (/^workbench$/i.test(options.taskType)) {
  console.warn(
    'Note: ADT uses Development/Correction for new tasks; Workbench is the transport request type (K), not tm:type on the task.',
  );
}

const createdTask = await createTransportTask(session.connection, {
  transportNumber,
  owner,
  description: options.description,
  taskType: options.taskType,
});

console.log(
  `Created task ${createdTask.taskNumber} on transport ${createdTask.requestNumber} for ${createdTask.owner} (tm:type=${normalizeTaskTypeForAdt(options.taskType)}).`,
);
