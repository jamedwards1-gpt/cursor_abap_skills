/**
 * Local ADT transport helper UI — binds 127.0.0.1 only. Uses repo .secrets/btp-abap.env (JWT).
 * Run from repo: npm run transport-ui
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import express from 'express';

import { connectAdtSession, loadAdtSession, readEnv, resolveTransportOwner, describeJwtIdentity, resolveTransportListUser, normalizeTransportListStatus } from '../../scripts/lib/adt-session.mjs';
import {
  getTransportOrganizerTreeXml,
  parseTransportAbapObjects,
  readTransport,
  resolveTransportTask,
} from '../../scripts/lib/adt-transport.mjs';
import {
  listOpenTransports,
  listPackageObjects,
  quickSearchObjects,
} from '../../scripts/lib/adt-object-catalog.mjs';
import { assignObjectsToTransport } from '../../scripts/lib/adt-assign-transport.mjs';
import { buildTransportOverview } from '../../scripts/lib/adt-transport-overview.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');
const defaultEnvPath = path.join(repoRoot, '.secrets', 'btp-abap.env');
const PORT = Number(process.env.TRANSPORT_UI_PORT || 3980);
const HOST = process.env.TRANSPORT_UI_HOST || '127.0.0.1';

function envPath() {
  return process.env.BTP_ADT_ENV || defaultEnvPath;
}

function redactUrl(url) {
  try {
    const u = new URL(url);
    return `${u.protocol}//${u.host}${u.pathname.slice(0, 48)}…`;
  } catch {
    return '[invalid]';
  }
}

async function withConnection(fn) {
  const session = await connectAdtSession(loadAdtSession(envPath()));
  try {
    return await fn(session);
  } finally {
    // no persistent pool
  }
}

function runRepoScript(scriptRel, args, extraEnv = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [path.join(repoRoot, scriptRel), ...args], {
      cwd: repoRoot,
      env: { ...process.env, ...extraEnv },
    });
    let out = '';
    let err = '';
    child.stdout?.on('data', (d) => {
      out += d.toString();
    });
    child.stderr?.on('data', (d) => {
      err += d.toString();
    });
    child.on('error', reject);
    child.on('close', (code) => {
      resolve({ code, stdout: out, stderr: err });
    });
  });
}

function organizerPayload(connection, trkorr) {
  return getTransportOrganizerTreeXml(connection, trkorr).then(({ status, xml, flavor, message }) => ({
    httpStatus: status,
    flavor: flavor || 'v1',
    note: message || null,
    xmlBytes: xml.length,
    abapObjects: parseTransportAbapObjects(xml),
    xmlPreview: xml.slice(0, 12000),
  }));
}

const app = express();
app.use(express.json({ limit: '12mb' }));
app.use(express.static(path.join(__dirname, '..', 'public')));

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, repoRoot, envPath: envPath() });
});

app.get('/api/config', (_req, res) => {
  const env = readEnv(envPath());
  const identity = describeJwtIdentity(env || {});
  res.json({
    envPath: envPath(),
    hasJwt: Boolean(env?.SAP_JWT_TOKEN),
    hasUrl: Boolean(env?.SAP_URL),
    sapClient: env?.SAP_CLIENT || '100',
    packageDefault: process.env.BTP_ADT_PACKAGE || 'ZPARCEL',
    transportOwner: process.env.BTP_ADT_TRANSPORT_OWNER || resolveTransportOwner(env) || '',
    identity,
    hint: 'Refresh JWT: npm run btp:auth -- --key .secrets/service-key.json',
  });
});

app.post('/api/connection/test', async (_req, res) => {
  try {
    const payload = await withConnection((session) => {
      const u = session.env?.SAP_URL || '';
      const identity = describeJwtIdentity(session.env);
      return {
        ok: true,
        system: redactUrl(u),
        envPath: session.envPath,
        identity,
      };
    });
    res.json(payload);
  } catch (e) {
    res.status(400).json({ ok: false, error: e?.message || String(e) });
  }
});

const SAP_SAFE_GET_PREFIXES = ['/sap/bc/', '/sap/opu/', '/default_host/'];

app.post('/api/sap-safe-get', async (req, res) => {
  const path = String(req.body?.path || '').trim();
  const accept = String(req.body?.accept || 'application/json, application/xml, text/plain, */*').trim();
  if (!path.startsWith('/')) {
    res.status(400).json({ error: 'path must start with /' });
    return;
  }
  if (path.length > 900) {
    res.status(400).json({ error: 'path too long (max 900 chars)' });
    return;
  }
  if (!SAP_SAFE_GET_PREFIXES.some((p) => path.startsWith(p))) {
    res.status(400).json({
      error: `path must start with one of: ${SAP_SAFE_GET_PREFIXES.join(', ')}`,
      allowedPrefixes: SAP_SAFE_GET_PREFIXES,
    });
    return;
  }
  try {
    const payload = await withConnection(async (session) => {
      const response = await session.connection.makeAdtRequest({
        url: path,
        method: 'GET',
        headers: { Accept: accept || '*/*' },
      });
      const raw = response.data;
      const text =
        typeof raw === 'string' ? raw : Buffer.isBuffer(raw) ? raw.toString('utf8') : JSON.stringify(raw);
      const max = 120000;
      const truncated = text.length > max;
      return {
        httpStatus: response.status,
        contentType: response.headers?.['content-type'] || response.headers?.['Content-Type'] || null,
        bodyLength: text.length,
        bodyTruncated: truncated,
        body: truncated ? text.slice(0, max) : text,
      };
    });
    res.json(payload);
  } catch (e) {
    res.status(502).json({
      error: e?.message || String(e),
      detail: e?.response?.data != null ? String(e.response.data).slice(0, 8000) : undefined,
      httpStatus: e?.response?.status,
    });
  }
});

app.get('/api/transports-overview', async (req, res) => {
  try {
    const env = readEnv(envPath());
    const userRes = resolveTransportListUser(req.query.user, env);
    const statusInput = String(req.query.status || '').trim();
    const status = normalizeTransportListStatus(statusInput);
    if (!userRes.user) {
      res.status(400).json({
        error: 'No SAP user for CTS list. Set SAP_USERNAME or JWT with BTP user id, or pass ?user=CB9980000010',
      });
      return;
    }
    const maxRequests = req.query.max ? Number(req.query.max) : 50;
    const includeOrganizer = req.query.organizers !== '0' && req.query.organizers !== 'false';
    const includeTaskOrganizers = req.query.taskOrganizers === '1' || req.query.taskOrganizers === 'true';
    const concurrency = req.query.concurrency ? Number(req.query.concurrency) : 4;
    const data = await withConnection((session) =>
      buildTransportOverview(session.connection, {
        user: userRes.user,
        status,
        maxRequests,
        concurrency,
        includeOrganizer,
        includeTaskOrganizers,
      }),
    );
    if (data.error) {
      res.status(400).json(data);
      return;
    }
    res.json({
      ...data,
      listUserQuery: String(req.query.user || '').trim() || null,
      listUserResolved: userRes.user,
      listUserResolution: userRes.source,
      listUserIgnoredQuery: userRes.ignoredQuery,
      statusFilterInput: statusInput || null,
      statusFilterUsed: status ?? null,
    });
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  }
});

app.get('/api/transports/:tr', async (req, res) => {
  const tr = String(req.params.tr || '').trim().toUpperCase();
  if (!tr) {
    res.status(400).json({ error: 'Missing transport number' });
    return;
  }
  try {
    const data = await withConnection(async (session) => {
      const meta = await readTransport(session.connection, tr);
      const organizer = await organizerPayload(session.connection, tr);
      return { transport: meta, organizer };
    });
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  }
});

app.get('/api/transports/:tr/task/:task', async (req, res) => {
  const task = String(req.params.task || '').trim().toUpperCase();
  if (!task) {
    res.status(400).json({ error: 'Missing task' });
    return;
  }
  try {
    const data = await withConnection(async (session) => {
      const organizer = await organizerPayload(session.connection, task);
      return { task, organizer };
    });
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  }
});

app.post('/api/transports/resolve-task', async (req, res) => {
  const { transportNumber, owner, taskNumber } = req.body || {};
  const tn = String(transportNumber || '').trim().toUpperCase();
  if (!tn) {
    res.status(400).json({ error: 'transportNumber required' });
    return;
  }
  try {
    const data = await withConnection(async (session) => {
      const env = session.env;
      const o = owner || resolveTransportOwner(env) || '';
      const resolved = await resolveTransportTask(session.connection, {
        transportNumber: tn,
        owner: o,
        taskNumber: String(taskNumber || '').trim().toUpperCase(),
      });
      return { transportNumber: tn, owner: o, taskNumber: resolved.taskNumber, reused: resolved.reused };
    });
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  }
});

app.post('/api/exec/push-class', async (req, res) => {
  const {
    className,
    source,
    transport,
    task,
    owner,
    create,
    recreate,
  } = req.body || {};
  const cn = String(className || '').trim().toUpperCase();
  const src = String(source || '');
  const tr = String(transport || '').trim().toUpperCase();
  const tk = String(task || '').trim().toUpperCase();
  if (!cn || !src || !tr) {
    res.status(400).json({ error: 'className, source, transport required' });
    return;
  }
  let tmp;
  try {
    tmp = path.join(repoRoot, `.transport-ui-${cn}-${Date.now()}.clas.abap`);
    fs.writeFileSync(tmp, src, 'utf8');
    const args = [cn, tmp, '--transport', tr];
    if (tk) {
      args.push('--task', tk);
    }
    if (create) {
      args.push('--create');
    }
    if (recreate) {
      args.push('--recreate');
    }
    const env = {
      BTP_ADT_TRANSPORT: tr,
      BTP_ADT_TASK: tk,
      BTP_ADT_PACKAGE: process.env.BTP_ADT_PACKAGE || 'ZPARCEL',
    };
    if (owner) {
      env.BTP_ADT_TRANSPORT_OWNER = owner;
    }
    const r = await runRepoScript('scripts/push-abap-class.mjs', args, env);
    res.json(r);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  } finally {
    if (tmp) {
      try {
        fs.unlinkSync(tmp);
      } catch {
        // ignore
      }
    }
  }
});

app.post('/api/exec/push-table', async (req, res) => {
  const { tableName, source, transport, task, package: pkg, owner } = req.body || {};
  const tn = String(tableName || '').trim().toUpperCase();
  const src = String(source || '');
  const tr = String(transport || '').trim().toUpperCase();
  const tk = String(task || '').trim().toUpperCase();
  const pk = String(pkg || 'ZPARCEL').toUpperCase();
  if (!tn || !src || !tr || !tk) {
    res.status(400).json({ error: 'tableName, source, transport, task required' });
    return;
  }
  let tmp;
  try {
    tmp = path.join(repoRoot, `.transport-ui-${tn}-${Date.now()}.tabl.abap`);
    fs.writeFileSync(tmp, src, 'utf8');
    const env = {
      BTP_ADT_TRANSPORT: tr,
      BTP_ADT_TASK: tk,
      BTP_ADT_PACKAGE: pk,
    };
    if (owner) {
      env.BTP_ADT_TRANSPORT_OWNER = owner;
    }
    const r = await runRepoScript('scripts/push-abap-table.mjs', [tn, tmp, pk], env);
    res.json(r);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  } finally {
    if (tmp) {
      try {
        fs.unlinkSync(tmp);
      } catch {
        // ignore
      }
    }
  }
});

app.post('/api/exec/push-ddls', async (req, res) => {
  const { viewName, source, transport, task, create, owner } = req.body || {};
  const vn = String(viewName || '').trim().toUpperCase();
  const src = String(source || '');
  const tr = String(transport || '').trim().toUpperCase();
  const tk = String(task || '').trim().toUpperCase();
  if (!vn || !src || !tr) {
    res.status(400).json({ error: 'viewName, source, transport required' });
    return;
  }
  let tmp;
  try {
    tmp = path.join(repoRoot, `.transport-ui-${vn}-${Date.now()}.asddls`);
    fs.writeFileSync(tmp, src, 'utf8');
    const args = [vn, tmp, '--transport', tr];
    if (tk) {
      args.push('--task', tk);
    }
    if (create) {
      args.push('--create');
    }
    const env = { BTP_ADT_TRANSPORT: tr, BTP_ADT_TASK: tk };
    if (owner) {
      env.BTP_ADT_TRANSPORT_OWNER = owner;
    }
    const r = await runRepoScript('scripts/push-abap-ddls.mjs', args, env);
    res.json(r);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  } finally {
    if (tmp) {
      try {
        fs.unlinkSync(tmp);
      } catch {
        // ignore
      }
    }
  }
});

app.post('/api/exec/create-task', async (req, res) => {
  const { transport, owner, description, taskType, listOnly } = req.body || {};
  const tr = String(transport || '').trim().toUpperCase();
  if (!tr) {
    res.status(400).json({ error: 'transport required' });
    return;
  }
  const args = ['--transport', tr];
  if (owner) {
    args.push('--owner', String(owner).trim());
  }
  if (description) {
    args.push('--description', String(description));
  }
  if (taskType) {
    args.push('--type', String(taskType));
  }
  if (listOnly) {
    args.push('--list');
  }
  const r = await runRepoScript('scripts/create-transport-task.mjs', args, {});
  res.json(r);
});

app.post('/api/exec/create-request', async (req, res) => {
  const { description } = req.body || {};
  const desc = String(description || 'Workbench request from transport-ui').trim();
  const r = await runRepoScript('scripts/create-transport-request.mjs', [desc], {});
  res.json(r);
});

app.post('/api/exec/transport-children', async (req, res) => {
  const tr = String(req.body?.transport || '').trim().toUpperCase();
  if (!tr) {
    res.status(400).json({ error: 'transport required' });
    return;
  }
  const args = [tr];
  if (req.body?.raw) {
    args.push('--raw');
  }
  const env = {};
  if (req.body?.owner) {
    env.BTP_ADT_TRANSPORT_OWNER = req.body.owner;
  }
  const r = await runRepoScript('scripts/list-transport-children.mjs', args, env);
  res.json(r);
});

app.post('/api/exec/experiment-bind', async (req, res) => {
  const { className, source, request, task, owner } = req.body || {};
  const cn = String(className || 'ZCL_TRANSPORT_UI_STATIC_JSON').trim().toUpperCase();
  const src = source ? String(source) : '';
  const rq = String(request || 'H01K900034').trim().toUpperCase();
  const tk = String(task || 'H01K900035').trim().toUpperCase();
  const env = {
    BTP_EXPERIMENT_REQUEST: rq,
    BTP_EXPERIMENT_TASK: tk,
  };
  if (owner) {
    env.BTP_ADT_TRANSPORT_OWNER = owner;
  }
  const args = [cn];
  let tmp;
  try {
    if (src) {
      tmp = path.join(repoRoot, `.transport-ui-exp-${cn}-${Date.now()}.clas.abap`);
      fs.writeFileSync(tmp, src, 'utf8');
      args.push(tmp);
    }
    const r = await runRepoScript('scripts/experiment-transport-bind.mjs', args, env);
    res.json(r);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  } finally {
    if (tmp) {
      try {
        fs.unlinkSync(tmp);
      } catch {
        // ignore
      }
    }
  }
});

app.get('/api/objects/search', async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (!q) {
    res.status(400).json({ error: 'Query parameter q is required' });
    return;
  }
  const objectType = String(req.query.type || '').trim();
  const maxResults = req.query.max ? Number(req.query.max) : 50;
  try {
    const data = await withConnection((session) =>
      quickSearchObjects(session.connection, {
        query: q,
        objectType,
        maxResults,
      }),
    );
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  }
});

app.get('/api/objects/package/:pkg', async (req, res) => {
  const pkg = String(req.params.pkg || '').trim().toUpperCase();
  if (!pkg) {
    res.status(400).json({ error: 'package required' });
    return;
  }
  const subpackages = req.query.subpackages !== '0' && req.query.subpackages !== 'false';
  try {
    const data = await withConnection((session) =>
      listPackageObjects(session.connection, pkg, { includeSubpackages: subpackages }),
    );
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  }
});

app.get('/api/transports-inbox', async (req, res) => {
  try {
    const data = await withConnection(async (session) => {
      const env = session.env;
      const userRes = resolveTransportListUser(req.query.user, env);
      const statusInput = String(req.query.status || '').trim();
      const status = normalizeTransportListStatus(statusInput);
      if (!userRes.user) {
        return { _error: 'No SAP user: set SAP_USERNAME / JWT user or ?user=CB9980000010' };
      }
      const list = await listOpenTransports(session.connection, {
        user: userRes.user,
        status,
      });
      return {
        ...list,
        listUserQuery: String(req.query.user || '').trim() || null,
        listUserResolved: userRes.user,
        listUserResolution: userRes.source,
        listUserIgnoredQuery: userRes.ignoredQuery,
        statusFilterInput: statusInput || null,
        statusFilterUsed: status ?? null,
      };
    });
    if (data._error) {
      res.status(400).json({ error: data._error });
      return;
    }
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  }
});

app.post('/api/objects/assign-transport', async (req, res) => {
  const { taskNumber, transportRequestNumber, objects } = req.body || {};
  const task = String(taskNumber || '').trim().toUpperCase();
  if (!task || !Array.isArray(objects) || objects.length === 0) {
    res.status(400).json({ error: 'taskNumber and non-empty objects[] required' });
    return;
  }
  try {
    const data = await withConnection((session) =>
      assignObjectsToTransport(session.connection, {
        taskNumber: task,
        transportRequestNumber: String(transportRequestNumber || '').trim().toUpperCase(),
        objects,
      }),
    );
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e?.message || String(e) });
  }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err?.message || String(err) });
});

const server = app.listen(PORT, HOST, () => {
  console.log(`Transport UI http://${HOST}:${PORT}`);
  console.log(`Repo: ${repoRoot}`);
  console.log(`ADT env: ${envPath()}`);
});

server.on('error', (err) => {
  if (err?.code === 'EADDRINUSE') {
    console.error(
      `Port ${PORT} is already in use (${HOST}). Run: npm --prefix transport-ui run stop`,
    );
    console.error('Or start without pre-stop: TRANSPORT_UI_NO_PRESTOP=1 npm run start:single');
    process.exit(1);
    return;
  }
  console.error(err);
  process.exit(1);
});
