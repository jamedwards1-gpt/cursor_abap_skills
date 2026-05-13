/**
 * Record ABAP objects on a transport task by lock(corrNr) + immediate unlock (ADT pattern).
 * Supported types: CLAS/OC, INTF/OI, INTF/IF, PROG/P, TABL/DT, DDLS/DF (CDS view).
 */
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { XMLParser } from 'fast-xml-parser';

import { lockClassForTransport } from './adt-class-lock.mjs';

const require = createRequire(import.meta.url);
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const encPath = path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/utils/internalUtils.js');
const ctPath = path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/constants/contentTypes.js');
const { encodeSapObjectName } = require(encPath);
const { ACCEPT_LOCK } = require(ctPath);
const { unlockClass } = require(path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/core/class/unlock.js'));
const { unlockInterface } = require(path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/core/interface/unlock.js'));
const { unlockProgram } = require(path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/core/program/unlock.js'));
const { unlockTable } = require(path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/core/table/unlock.js'));
const { unlockDDLS } = require(path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/core/view/unlock.js'));

const lockParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
});

function parseLockData(xml) {
  const result = lockParser.parse(xml);
  const data = result?.['asx:abap']?.['asx:values']?.DATA;
  return {
    lockHandle: data?.LOCK_HANDLE,
    corrNr: data?.CORRNR,
    isLocal: data?.IS_LOCAL === 'X',
  };
}

async function postLockUnlock(connection, { lockUrl, unlockFn, objectName, label }) {
  const response = await connection.makeAdtRequest({
    url: lockUrl,
    method: 'POST',
    data: null,
    headers: { Accept: ACCEPT_LOCK },
  });
  const { lockHandle, corrNr, isLocal } = parseLockData(String(response.data ?? ''));
  if (!lockHandle) {
    throw new Error(`${label}: no lock handle from ADT`);
  }
  try {
    await unlockFn(connection, objectName, lockHandle);
  } catch (e) {
    const msg = e?.response?.data ? String(e.response.data).slice(0, 400) : e?.message || String(e);
    throw new Error(`${label}: unlock failed: ${msg}`);
  }
  return { lockHandle, corrNr, isLocal };
}

function normType(t) {
  return String(t || '').trim().toUpperCase();
}

/**
 * @param {object} connection
 * @param {object} opts
 * @param {string} opts.taskNumber - CTS task (corrNr), e.g. H01K900035
 * @param {string} [opts.transportRequestNumber] - Parent request when task lock is "local only"
 * @param {Array<{ name: string, adtType: string }>} opts.objects
 */
export async function assignObjectsToTransport(connection, { taskNumber, transportRequestNumber, objects }) {
  const task = String(taskNumber || '').trim().toUpperCase();
  const parent = String(transportRequestNumber || '').trim().toUpperCase();
  if (!task) {
    throw new Error('taskNumber is required');
  }
  const list = (objects || []).map((o) => ({
    name: String(o.name || '').trim().toUpperCase(),
    adtType: normType(o.adtType),
  })).filter((o) => o.name && o.adtType);

  if (list.length === 0) {
    return { results: [], message: 'No objects' };
  }

  if (typeof connection.setSessionType === 'function') {
    connection.setSessionType('stateful');
  }

  const results = [];
  try {
    for (const obj of list) {
      const { name, adtType } = obj;
      const t = adtType;
      try {
        if (t.startsWith('CLAS/')) {
          const { lockHandle } = await lockClassForTransport(connection, name, task, {
            transportRequestNumber: parent || task,
          });
          await unlockClass(connection, name, lockHandle);
          results.push({ name, adtType: t, ok: true, method: 'class-lock' });
          continue;
        }

        if (t.startsWith('INTF/')) {
          const enc = encodeSapObjectName(name).toLowerCase();
          const lockUrl = `/sap/bc/adt/oo/interfaces/${enc}?_action=LOCK&accessMode=MODIFY&corrNr=${encodeURIComponent(task)}`;
          await postLockUnlock(connection, {
            lockUrl,
            unlockFn: unlockInterface,
            objectName: name,
            label: `INTF ${name}`,
          });
          results.push({ name, adtType: t, ok: true, method: 'interface-lock' });
          continue;
        }

        if (t === 'PROG/P' || t.startsWith('PROG/')) {
          const enc = encodeSapObjectName(name).toLowerCase();
          const lockUrl = `/sap/bc/adt/programs/programs/${enc}?_action=LOCK&accessMode=MODIFY&corrNr=${encodeURIComponent(task)}`;
          await postLockUnlock(connection, {
            lockUrl,
            unlockFn: unlockProgram,
            objectName: name,
            label: `PROG ${name}`,
          });
          results.push({ name, adtType: t, ok: true, method: 'program-lock' });
          continue;
        }

        if (t.startsWith('TABL/') || t === 'TABL') {
          const enc = encodeSapObjectName(name);
          const lockUrl = `/sap/bc/adt/ddic/tables/${enc}?_action=LOCK&accessMode=MODIFY&corrNr=${encodeURIComponent(task)}`;
          await postLockUnlock(connection, {
            lockUrl,
            unlockFn: unlockTable,
            objectName: name,
            label: `TABL ${name}`,
          });
          results.push({ name, adtType: t, ok: true, method: 'table-lock' });
          continue;
        }

        if (t.startsWith('DDLS/')) {
          const enc = encodeSapObjectName(name).toLowerCase();
          const lockUrl = `/sap/bc/adt/ddic/ddl/sources/${enc}?_action=LOCK&accessMode=MODIFY&corrNr=${encodeURIComponent(task)}`;
          await postLockUnlock(connection, {
            lockUrl,
            unlockFn: unlockDDLS,
            objectName: name,
            label: `DDLS ${name}`,
          });
          results.push({ name, adtType: t, ok: true, method: 'ddls-lock' });
          continue;
        }

        results.push({
          name,
          adtType: t,
          ok: false,
          error: `Unsupported type for transport assignment: ${t}. Use ADT or push scripts for this object type.`,
        });
      } catch (e) {
        results.push({
          name,
          adtType: t,
          ok: false,
          error: e?.response?.data ? String(e.response.data).slice(0, 500) : e?.message || String(e),
        });
      }
    }
  } finally {
    if (typeof connection.setSessionType === 'function') {
      connection.setSessionType('stateless');
    }
  }

  return { taskNumber: task, transportRequestNumber: parent || null, results };
}
