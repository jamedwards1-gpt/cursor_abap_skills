import { connectAdtSession, loadAdtSession } from './lib/adt-session.mjs';
import { createTransportTask, readTransport } from './lib/adt-transport.mjs';

function parseArgs(argv) {
  const options = {
    transport: process.env.BTP_ADT_TRANSPORT || '',
    owner: process.env.BTP_ADT_TRANSPORT_OWNER || '',
    description: process.env.BTP_ADT_TASK_DESCRIPTION || 'Cursor ADT class update',
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
    if (arg === '--list') {
      options.listOnly = true;
    }
  }

  return options;
}

const options = parseArgs(process.argv.slice(2));
if (!options.transport) {
  console.error(
    'Usage: node scripts/create-transport-task.mjs --transport <REQUEST> [--owner <SAP_USER>] [--description <TEXT>] [--list]',
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

const createdTask = await createTransportTask(session.connection, {
  transportNumber,
  owner,
  description: options.description,
});

console.log(
  `Created task ${createdTask.taskNumber} on transport ${createdTask.requestNumber} for ${createdTask.owner}.`,
);
