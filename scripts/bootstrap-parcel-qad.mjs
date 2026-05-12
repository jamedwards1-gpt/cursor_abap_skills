import { spawn } from 'node:child_process';
import path from 'node:path';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';
import { createTransportTask, readTransport } from './lib/adt-transport.mjs';

const description = process.argv.slice(2).join(' ').trim() || 'Parcel QAD polling rebuild';
const packageName = (process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase();

if (!process.env.BTP_ADT_TRANSPORT_OWNER) {
  console.error(
    'Set BTP_ADT_TRANSPORT_OWNER to your ABAP user (for example CB9980000010) before running btp:bootstrap-parcel.',
  );
  process.exit(1);
}

function runNode(scriptPath, args = [], env = process.env) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath, ...args], {
      stdio: ['ignore', 'pipe', 'inherit'],
      env,
    });

    let stdout = '';
    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });

    child.on('exit', (code) => {
      if (code === 0) {
        resolve(stdout.trim());
        return;
      }

      reject(new Error(`${path.basename(scriptPath)} failed with exit code ${code}.`));
    });
  });
}

const transportNumber = await runNode(
  path.resolve('scripts/create-transport-request.mjs'),
  [description],
  {
    ...process.env,
    BTP_ADT_TRANSPORT_OWNER: process.env.BTP_ADT_TRANSPORT_OWNER || '',
  },
);
console.log(`Created transport request ${transportNumber}.`);

const session = await connectAdtSession(loadAdtSession());
let taskOwner = resolveTransportOwner(session.env);
const transport = await readTransport(session.connection, transportNumber);

if (!taskOwner) {
  taskOwner = transport.owner;
}

if (!taskOwner) {
  throw new Error('Transport owner is required. Set BTP_ADT_TRANSPORT_OWNER or refresh btp:auth.');
}

let taskNumber = transport.tasks.find((task) => task.owner === taskOwner && task.status === 'D')?.number;
if (!taskNumber) {
  const createdTask = await createTransportTask(session.connection, {
    transportNumber,
    owner: taskOwner,
    description: 'Parcel QAD bootstrap',
  });
  taskNumber = createdTask.taskNumber;
  console.log(`Created transport task ${taskNumber} for ${taskOwner}.`);
} else {
  console.log(`Reusing modifiable task ${taskNumber} for ${taskOwner}.`);
}

const env = {
  ...process.env,
  BTP_ADT_TRANSPORT: transportNumber,
  BTP_ADT_TASK: taskNumber,
  BTP_ADT_PACKAGE: packageName,
  BTP_ADT_CREATE: '1',
};

await runNode(
  path.resolve('scripts/create-abap-package.mjs'),
  [packageName, transportNumber, 'Parcel QAD integration and polling'],
  env,
);

const tables = [
  ['ZPARCEL_POLL_LOG', 'btp-content/abap/ZPARCEL/TABL_DT/ZPARCEL_POLL_LOG.tabl.abap'],
  ['ZPARCEL_TRC_H', 'btp-content/abap/ZPARCEL/TABL_DT/ZPARCEL_TRC_H.tabl.abap'],
  ['ZPARCEL_TRC_P', 'btp-content/abap/ZPARCEL/TABL_DT/ZPARCEL_TRC_P.tabl.abap'],
];

for (const [tableName, sourcePath] of tables) {
  await runNode(
    path.resolve('scripts/push-abap-table.mjs'),
    [tableName, sourcePath, packageName],
    env,
  );
}

await runNode(path.resolve('scripts/push-parcel-qad.mjs'), ['--create'], env);

console.log(
  [
    'Parcel QAD bootstrap complete.',
    `Transport request: ${transportNumber}`,
    `Task: ${taskNumber}`,
    `Package: ${packageName}`,
    'Next: npm run btp:sync-package -- ZPARCEL',
  ].join('\n'),
);
