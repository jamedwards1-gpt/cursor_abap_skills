/**
 * Put ZPARCEL / QAD mirror content onto one transport request + task, then refresh APJ catalog + template.
 *
 * Usage:
 *   BTP_ADT_TRANSPORT_OWNER=CB9980000010 npm run btp:parcel-consolidate -- H01K900034
 *     → reuse request H01K900034 (resolve modifiable task, e.g. H01K900035)
 *
 *   BTP_ADT_TASK=H01K900031 BTP_ADT_TRANSPORT_OWNER=CB9980000010 npm run btp:parcel-consolidate -- H01K900030
 *     → reuse request H01K900030 and **force** corrNr to task H01K900031 (skip auto-pick)
 *
 *   BTP_ADT_TRANSPORT_OWNER=CB9980000010 npm run btp:parcel-consolidate
 *     → create a new Workbench request + task, then push everything there
 *
 * Requires: npm run btp:auth, .secrets/btp-abap.env
 */
import path from 'node:path';
import { spawn } from 'node:child_process';
import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';
import { readTransport, resolveTransportTask } from './lib/adt-transport.mjs';

const root = 'btp-content/abap/ZPARCEL';
const packageName = (process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase();

function runNode(scriptPath, args, env) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [path.resolve(scriptPath), ...args], {
      stdio: 'inherit',
      env: { ...process.env, ...env },
    });
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${path.basename(scriptPath)} exited ${code}`));
    });
  });
}

async function optionalStep(label, fn) {
  try {
    await fn();
  } catch (e) {
    console.warn(`[skip] ${label}: ${e?.message || e}`);
  }
}

const reuseRequest = (process.argv[2] || process.env.BTP_PARCEL_CONSOLIDATE_REQUEST || '').trim().toUpperCase();

const session = await connectAdtSession(loadAdtSession());
const { connection } = session;
const owner = resolveTransportOwner(session.env);
if (!owner) {
  console.error('Set BTP_ADT_TRANSPORT_OWNER (or SAP user in .secrets/btp-abap.env).');
  process.exit(1);
}

let transportRequest;
if (reuseRequest) {
  transportRequest = reuseRequest;
  console.log(`Reusing transport request ${transportRequest}.`);
} else {
  const client = new AdtClient(connection);
  const desc = process.env.BTP_PARCEL_CONSOLIDATE_DESC || 'ZPARCEL QAD consolidated (sandbox)';
  const state = await client.getRequest().create({
    description: desc,
    transportType: 'workbench',
    owner,
  });
  transportRequest =
    state.transportNumber ||
    state.createResult?.data?.transport_request ||
    state.createResult?.data?.transport_number;
  if (!transportRequest) {
    console.error('Could not read new transport request number from ADT response.');
    process.exit(1);
  }
  console.log(`Created transport request ${transportRequest}: ${desc}`);
}

const explicitTask = (process.env.BTP_ADT_TASK || '').trim().toUpperCase();
const resolved = await resolveTransportTask(connection, {
  transportNumber: transportRequest,
  owner,
  taskNumber: explicitTask,
});
const taskNumber = resolved.taskNumber;
if (explicitTask) {
  console.log(`Using explicit task (corrNr) ${taskNumber} on request ${transportRequest} (from BTP_ADT_TASK).`);
} else {
  console.log(`Using task (corrNr) ${taskNumber} for owner ${owner}.`);
}

const env = {
  ...process.env,
  BTP_ADT_TRANSPORT: transportRequest,
  BTP_ADT_TASK: taskNumber,
  BTP_ADT_PACKAGE: packageName,
};

const tables = [
  ['ZPARCEL_POLL_LOG', `${root}/TABL_DT/ZPARCEL_POLL_LOG.tabl.abap`],
  ['ZPARCEL_TRC_H', `${root}/TABL_DT/ZPARCEL_TRC_H.tabl.abap`],
  ['ZPARCEL_TRC_P', `${root}/TABL_DT/ZPARCEL_TRC_P.tabl.abap`],
];

for (const [tableName, relPath] of tables) {
  await runNode('scripts/push-abap-table.mjs', [tableName, path.resolve(relPath), packageName], env);
}

await runNode('scripts/push-parcel-qad.mjs', [], env);

await optionalStep('Application Job catalog', () =>
  runNode('scripts/create-apj-catalog.mjs', [], {
    ...env,
    BTP_ADT_TRANSPORT_OWNER: owner,
  }),
);

await optionalStep('Application Job template', () =>
  runNode('scripts/create-apj-job-template.mjs', [], {
    ...env,
    BTP_ADT_TRANSPORT_OWNER: owner,
  }),
);

console.log('');
console.log('--- ZPARCEL consolidated onto one line ---');
console.log(`export BTP_ADT_TRANSPORT=${transportRequest}`);
console.log(`export BTP_ADT_TASK=${taskNumber}`);
console.log(`export BTP_ADT_TRANSPORT_OWNER=${owner}`);
console.log(`export BTP_ADT_PACKAGE=${packageName}`);
console.log('Add the above to your shell or .secrets/btp-abap.env for future pushes.');
console.log('Verify CTS lines in ADT: npm run btp:transport-children -- ' + transportRequest);
