/**
 * Try several delete+create strategies so new ABAP objects bind to a CTS task like Eclipse,
 * then read Transport Organizer v1+xml and count tm:abap_object rows (task + request).
 *
 * Defaults: request H01K900034, task H01K900035, class ZCL_TRANSPORT_UI_STATIC_JSON.
 *
 *   BTP_ADT_TRANSPORT_OWNER=CB9980000010 node scripts/experiment-transport-bind.mjs
 *   node scripts/experiment-transport-bind.mjs ZCL_MY_CLASS /path/to.clas.abap
 *
 * Requires: npm run btp:auth
 */
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';
import {
  getTransportOrganizerTreeXml,
  parseTransportAbapObjects,
} from './lib/adt-transport.mjs';
import { lockClassForTransport } from './lib/adt-class-lock.mjs';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);
const adtClassRoot = path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/core/class');
const { create } = require(path.join(adtClassRoot, 'create.js'));
const { deleteClass } = require(path.join(adtClassRoot, 'delete.js'));
const { updateClassWithCheck } = require(path.join(adtClassRoot, 'update.js'));
const { activateClass } = require(path.join(adtClassRoot, 'activation.js'));
const { unlockClass } = require(path.join(adtClassRoot, 'unlock.js'));

const REQUEST = (process.env.BTP_EXPERIMENT_REQUEST || 'H01K900034').toUpperCase();
const TASK = (process.env.BTP_EXPERIMENT_TASK || 'H01K900035').toUpperCase();
const packageName = (process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase();

const argv = process.argv.slice(2).filter((a) => !a.startsWith('-'));
const className = (argv[0] || 'ZCL_TRANSPORT_UI_STATIC_JSON').toUpperCase();
const sourcePath = argv[1]
  ? path.resolve(argv[1])
  : path.join(repoRoot, 'btp-content/abap/ZPARCEL/CLAS_OC', `${className}.clas.abap`);

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

async function classExists(adtClient, name) {
  try {
    await adtClient.getClass().readMetadata({ className: name });
    return true;
  } catch {
    return false;
  }
}

async function transportSnapshot(connection, trkorr, needle) {
  const { xml, flavor } = await getTransportOrganizerTreeXml(connection, trkorr);
  const objs = parseTransportAbapObjects(xml);
  const n = needle.toUpperCase();
  const hits = objs.filter((o) => (o.name || '').toUpperCase().includes(n));
  return {
    trkorr,
    flavor,
    totalAbapObjects: objs.length,
    hitsForClass: hits.length,
    hitsPreview: hits.slice(0, 12).map((o) => `${o.type || '?'}\t${o.name}`),
  };
}

async function printSnapshots(connection, label, needle) {
  const req = await transportSnapshot(connection, REQUEST, needle);
  const task = await transportSnapshot(connection, TASK, needle);
  console.log(`  [cts] ${label}`);
  console.log(`        request ${REQUEST}: total tm:abap_object=${req.totalAbapObjects} matching=${req.hitsForClass}`);
  if (req.hitsPreview.length) {
    for (const line of req.hitsPreview) {
      console.log(`          ${line}`);
    }
  }
  console.log(`        task ${TASK}: total tm:abap_object=${task.totalAbapObjects} matching=${task.hitsForClass}`);
  if (task.hitsPreview.length) {
    for (const line of task.hitsPreview) {
      console.log(`          ${line}`);
    }
  }
}

async function hardDelete(connection, adtClient, name) {
  const attempts = [
    { label: 'local', tr: '' },
    { label: `task ${TASK}`, tr: TASK },
    { label: `request ${REQUEST}`, tr: REQUEST },
  ];
  for (const a of attempts) {
    try {
      await deleteClass(connection, { class_name: name, transport_request: a.tr });
      console.warn(`  [del] ${a.label} OK`);
    } catch (e) {
      console.warn(`  [del] ${a.label}: ${String(e?.response?.data || e?.message || e).slice(0, 160)}`);
    }
    await refreshAdtConnection(connection);
    if (!(await classExists(adtClient, name))) {
      return true;
    }
  }
  return !(await classExists(adtClient, name));
}

async function updatePipeline(connection, name, sourceCode) {
  connection.setSessionType('stateful');
  const { lockHandle, corrNr } = await lockClassForTransport(connection, name, TASK, {
    transportRequestNumber: REQUEST,
  });
  await updateClassWithCheck(connection, name, sourceCode, lockHandle, corrNr);
  await unlockClass(connection, name, lockHandle);
  connection.setSessionType('stateless');
  await activateClass(connection, name);
}

function runNodeScript(relScript, args, extraEnv = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [path.join(repoRoot, relScript), ...args], {
      stdio: 'inherit',
      env: { ...process.env, ...extraEnv, BTP_ADT_PACKAGE: packageName },
    });
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${relScript} exited ${code}`));
    });
  });
}

if (!fs.existsSync(sourcePath)) {
  console.error(`Missing source: ${sourcePath}`);
  process.exit(1);
}

const sourceCode = fs.readFileSync(sourcePath, 'utf8');
const session = await connectAdtSession(loadAdtSession());
const owner = resolveTransportOwner(session.env);
if (!owner) {
  console.error('Set BTP_ADT_TRANSPORT_OWNER or SAP user in .secrets/btp-abap.env');
  process.exit(1);
}

const { connection } = session;
const adtClient = new AdtClient(connection);

console.log(`Experiment: ${className}`);
console.log(`Parent request ${REQUEST}, task ${TASK}, owner ${owner}, package ${packageName}`);
console.log(`Source: ${sourcePath}`);

await printSnapshots(connection, 'before any changes', className);

const ideas = [];

/** Idea 1 — same as CLI --recreate (local→task→request delete, session refresh, AdtClass.create). */
ideas.push({
  name: '1) push-abap-class --recreate (Eclipse-like pipeline)',
  async run() {
    await runNodeScript(
      'scripts/push-abap-class.mjs',
      [className, sourcePath, '--transport', REQUEST, '--task', TASK, '--recreate'],
      { BTP_ADT_TRANSPORT: REQUEST, BTP_ADT_TASK: TASK, BTP_ADT_TRANSPORT_OWNER: owner },
    );
  },
});

/** Idea 2 — low-level POST /oo/classes?corrNr=<TASK> then update/activate. */
ideas.push({
  name: '2) Low-level create() with corrNr = TASK only',
  async run() {
    connection.setSessionType('stateful');
    await create(
      connection,
      {
        class_name: className,
        package_name: packageName,
        transport_request: TASK,
      },
      null,
      null,
    );
    connection.setSessionType('stateless');
    await updatePipeline(connection, className, sourceCode);
  },
});

/** Idea 3 — low-level create with corrNr = parent REQUEST (some systems record on K). */
ideas.push({
  name: '3) Low-level create() with corrNr = parent REQUEST',
  async run() {
    connection.setSessionType('stateful');
    await create(
      connection,
      {
        class_name: className,
        package_name: packageName,
        transport_request: REQUEST,
      },
      null,
      null,
    );
    connection.setSessionType('stateless');
    await updatePipeline(connection, className, sourceCode);
  },
});

/** Idea 4 — delete with TASK first only (skip empty local), then create TASK. */
ideas.push({
  name: '4) Delete task-only first, then create TASK',
  async run() {
    try {
      await deleteClass(connection, { class_name: className, transport_request: TASK });
      console.warn('  [del] task-only first OK');
    } catch (e) {
      console.warn(`  [del] task-only: ${String(e?.response?.data || e?.message || e).slice(0, 160)}`);
    }
    await refreshAdtConnection(connection);
    connection.setSessionType('stateful');
    await create(
      connection,
      {
        class_name: className,
        package_name: packageName,
        transport_request: TASK,
      },
      null,
      null,
    );
    connection.setSessionType('stateless');
    await updatePipeline(connection, className, sourceCode);
  },
});

/** Idea 5 — high-level AdtClass.delete (checkDeletion+stateful delete) then AdtClass.create. */
ideas.push({
  name: '5) AdtClass.delete({ transportRequest: TASK }) then AdtClass.create',
  async run() {
    if (await classExists(adtClient, className)) {
      try {
        await adtClient.getClass().delete({ className, transportRequest: TASK });
      } catch (e) {
        console.warn(`  [del] AdtClass.delete: ${String(e?.response?.data || e?.message || e).slice(0, 200)}`);
      }
    }
    await refreshAdtConnection(connection);
    await adtClient.getClass().create(
      {
        className,
        packageName,
        transportRequest: TASK,
        sourceCode,
      },
      { sourceCode },
    );
    connection.setSessionType('stateless');
    await updatePipeline(connection, className, sourceCode);
  },
});

/** Idea 6 — create with TASK + adtcore:responsible = owner (Eclipse often sets “responsible”). */
ideas.push({
  name: '6) Low-level create TASK + responsible = transport owner',
  async run() {
    connection.setSessionType('stateful');
    await create(
      connection,
      {
        class_name: className,
        package_name: packageName,
        transport_request: TASK,
        responsible: owner,
      },
      null,
      null,
    );
    connection.setSessionType('stateless');
    await updatePipeline(connection, className, sourceCode);
  },
});

for (let i = 0; i < ideas.length; i += 1) {
  const idea = ideas[i];
  console.log('\n============================================================');
  console.log(idea.name);
  console.log('============================================================');

  const gone = await hardDelete(connection, adtClient, className);
  if (!gone && (await classExists(adtClient, className))) {
    console.error('  [skip] Class still exists after deletes; fix locks in ADT and re-run.');
    await printSnapshots(connection, 'after failed delete', className);
    continue;
  }

  try {
    await idea.run();
    console.log('  [ok] Idea completed without throw.');
  } catch (e) {
    console.error(`  [fail] ${e?.message || e}`);
    await printSnapshots(connection, 'after failure', className);
    continue;
  }

  await printSnapshots(connection, `after idea ${i + 1}`, className);
}

console.log('\nDone. If no tm:abap_object hits, CTS may still omit E071 for API edits; compare with SE01.');
console.log(`Inspect XML: npm run btp:transport-children -- ${REQUEST} --raw`);
