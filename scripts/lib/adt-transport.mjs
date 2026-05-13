import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { XMLParser } from 'fast-xml-parser';

const require = createRequire(import.meta.url);
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const contentTypesPath = path.join(
  repoRoot,
  'node_modules/@mcp-abap-adt/adt-clients/dist/constants/contentTypes.js',
);
const { ACCEPT_TRANSPORT, ACCEPT_TRANSPORT_LIST } = require(contentTypesPath);

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  parseAttributeValue: false,
  trimValues: true,
});

function asArray(value) {
  if (value === undefined || value === null) {
    return [];
  }

  return Array.isArray(value) ? value : [value];
}

function escapeXml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

/** ADT `tm:type` on a transport *task* is not the same as a Workbench *request* (K). */
export function normalizeTaskTypeForAdt(taskType) {
  const raw = (taskType ?? 'Development/Correction').trim();
  if (!raw) {
    return 'Development/Correction';
  }
  if (/^workbench$/i.test(raw)) {
    return 'Development/Correction';
  }
  return raw;
}

function transportUrl(transportNumber) {
  return `/sap/bc/adt/cts/transportrequests/${encodeURIComponent(transportNumber)}`;
}

/**
 * GET transport XML suitable for listing organizer “children” (object URIs when present).
 * Tries `transportorganizertree.v1+xml` first (on-prem Eclipse); on **406** (typical ABAP Environment /
 * Steampunk) falls back to `transportorganizer.v1+xml` — same URL, which is all the system accepts.
 */
export async function getTransportOrganizerTreeXml(connection, transportNumber) {
  const normalized = String(transportNumber).toUpperCase();
  const url = transportUrl(normalized);
  try {
    const response = await connection.makeAdtRequest({
      url,
      method: 'GET',
      headers: { Accept: ACCEPT_TRANSPORT_LIST },
    });
    return {
      status: response.status,
      xml: String(response.data ?? ''),
      flavor: 'tree',
    };
  } catch (error) {
    const status = error?.response?.status;
    const body = String(error?.response?.data ?? '');
    const steampunkStyle406 =
      status === 406 &&
      (body.includes('ExceptionResourceNotAcceptable') ||
        body.includes('transportorganizer.v1+xml') ||
        body.includes('SADT_RESOURCE'));
    if (!steampunkStyle406) {
      throw error;
    }
    const response = await connection.makeAdtRequest({
      url,
      method: 'GET',
      headers: { Accept: ACCEPT_TRANSPORT },
    });
    return {
      status: response.status,
      xml: String(response.data ?? ''),
      flavor: 'v1-fallback',
      message:
        'This system does not offer transportorganizertree for this resource (406). '
        + 'Using transportorganizer.v1+xml instead — object lines appear here when CTS records them.',
    };
  }
}

/**
 * GET transport request metadata (tasks, status) — same payload as {@link readTransport} source.
 */
export async function getTransportOrganizerV1Xml(connection, transportNumber) {
  const normalized = String(transportNumber).toUpperCase();
  const response = await connection.makeAdtRequest({
    url: transportUrl(normalized),
    method: 'GET',
    headers: { Accept: ACCEPT_TRANSPORT },
  });
  return { status: response.status, xml: String(response.data ?? '') };
}

function parseTransportPayload(xml) {
  const root = parser.parse(xml);
  const tmRoot = root['tm:root'] ?? root.root;
  if (!tmRoot) {
    throw new Error('Transport response did not contain tm:root.');
  }

  const request = tmRoot['tm:request'] ?? tmRoot.request;
  if (!request) {
    throw new Error('Transport response did not contain tm:request.');
  }

  const tasks = asArray(request['tm:task'] ?? request.task).map((task) => ({
    number: task['tm:number'] ?? task.number,
    parent: task['tm:parent'] ?? task.parent,
    owner: task['tm:owner'] ?? task.owner,
    description: task['tm:desc'] ?? task.desc,
    status: task['tm:status'] ?? task.status,
    statusText: task['tm:status_text'] ?? task.status_text,
  }));

  return {
    number: request['tm:number'] ?? request.number,
    owner: request['tm:owner'] ?? request.owner,
    description: request['tm:desc'] ?? request.desc,
    status: request['tm:status'] ?? request.status,
    statusText: request['tm:status_text'] ?? request.status_text,
    tasks,
  };
}

/**
 * Extract `tm:abap_object` entries from Transport Organizer v1+xml (Steampunk / on-prem).
 */
export function parseTransportAbapObjects(xml) {
  const fromTags = [];
  const tagRe = /<tm:abap_object\b([^>]*)\/>/gi;
  let match = tagRe.exec(xml);
  while (match !== null) {
    const attrs = match[1];
    const name = /adtcore:name="([^"]*)"/i.exec(attrs)?.[1];
    const uri = /adtcore:uri="([^"]*)"/i.exec(attrs)?.[1];
    const typ = /adtcore:type="([^"]*)"/i.exec(attrs)?.[1];
    if (name || uri) {
      fromTags.push({ name, uri, type: typ });
    }
    match = tagRe.exec(xml);
  }
  const openRe = /<tm:abap_object\b([^>]*)>([\s\S]*?)<\/tm:abap_object>/gi;
  match = openRe.exec(xml);
  while (match !== null) {
    const attrs = match[1];
    const name = /adtcore:name="([^"]*)"/i.exec(attrs)?.[1];
    const uri = /adtcore:uri="([^"]*)"/i.exec(attrs)?.[1];
    const typ = /adtcore:type="([^"]*)"/i.exec(attrs)?.[1];
    if (name || uri) {
      fromTags.push({ name, uri, type: typ });
    }
    match = openRe.exec(xml);
  }

  let root;
  try {
    root = parser.parse(xml);
  } catch {
    return dedupeObjects(fromTags);
  }

  const out = [...fromTags];

  function visit(node) {
    if (node === undefined || node === null) {
      return;
    }
    if (Array.isArray(node)) {
      for (const x of node) {
        visit(x);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }

    for (const [k, v] of Object.entries(node)) {
      const isAbap = k === 'tm:abap_object' || k.endsWith(':abap_object');
      if (isAbap) {
        for (const item of asArray(v)) {
          if (item && typeof item === 'object') {
            out.push({
              name: item['adtcore:name'] ?? item.name,
              uri: item['adtcore:uri'] ?? item.uri,
              type: item['adtcore:type'] ?? item.type,
            });
          }
        }
      }
      visit(v);
    }
  }

  visit(root);
  return dedupeObjects(out.filter((o) => o.name || o.uri));
}

function dedupeObjects(rows) {
  const seen = new Set();
  const out = [];
  for (const o of rows) {
    const k = `${o.name || ''}|${o.uri || ''}`;
    if (seen.has(k)) {
      continue;
    }
    seen.add(k);
    out.push(o);
  }
  return out;
}

function parseTaskCreationPayload(xml) {
  const root = parser.parse(xml);
  const tmRoot = root['tm:root'] ?? root.root;
  const request = tmRoot?.['tm:request'] ?? tmRoot?.request;
  const task = request?.['tm:task'] ?? request?.task;

  if (!task) {
    throw new Error('Task creation response did not contain a task number.');
  }

  return {
    requestNumber: request?.['tm:number'] ?? request?.number,
    taskNumber: task['tm:number'] ?? task.number,
    owner: task['tm:owner'] ?? task.owner,
    description: task['tm:desc'] ?? task.desc,
    status: task['tm:status'] ?? task.status,
    statusText: task['tm:status_text'] ?? task.status_text,
  };
}

export async function readTransport(connection, transportNumber) {
  const normalized = String(transportNumber).toUpperCase();
  const response = await connection.makeAdtRequest({
    url: transportUrl(normalized),
    method: 'GET',
    headers: { Accept: ACCEPT_TRANSPORT },
  });

  const parsed = parseTransportPayload(String(response.data));
  // ADT GET by transport *task* number (e.g. H01K900033) returns the parent *request* (H01K900032)
  // but often omits inlined tasks. Refetch once by request number so resolveTransportTask sees tasks.
  if (
    parsed.tasks.length === 0 &&
    parsed.number &&
    parsed.number.toUpperCase() !== normalized
  ) {
    return readTransport(connection, parsed.number);
  }

  return parsed;
}

/**
 * @param {object} params
 * @param {string} params.transportNumber - Transport **request** number, or a **task** number (resolved to parent request).
 * @param {string} params.owner - SAP user that owns the new task.
 * @param {string} params.description - Task description.
 * @param {string} [params.taskType='Development/Correction'] - `tm:type` on the new task. Values such as `Workbench` are normalized: Workbench is the *request* category (K), not a task `tm:type` in ADT.
 */
export async function createTransportTask(connection, {
  transportNumber,
  owner,
  description,
  taskType = 'Development/Correction',
}) {
  const transport = await readTransport(connection, transportNumber);
  const requestNumber = transport.number;
  const normalizedType = normalizeTaskTypeForAdt(taskType);
  const typeAttr = ` tm:type="${escapeXml(normalizedType)}"`;

  const xml = [
    '<?xml version="1.0" encoding="ASCII"?>',
    '<tm:root xmlns:tm="http://www.sap.com/cts/adt/tm" tm:useraction="newtask">',
  `  <tm:request tm:number="${escapeXml(requestNumber)}">`,
  `    <tm:task tm:owner="${escapeXml(owner)}" tm:desc="${escapeXml(description)}"${typeAttr}/>`,
    '  </tm:request>',
    '</tm:root>',
  ].join('\n');

  let response;
  try {
    response = await connection.makeAdtRequest({
      url: `${transportUrl(requestNumber)}/tasks`,
      method: 'POST',
      data: xml,
      headers: {
        Accept: ACCEPT_TRANSPORT,
        'Content-Type': 'text/plain',
      },
    });
  } catch (error) {
    const body = String(error?.response?.data ?? '');
    const isUser009 =
      error?.response?.status === 400 &&
      (body.includes('SCTS_ADT_MSG') || body.includes('does not exist in the system'));
    if (isUser009) {
      throw new Error(
        [
          'ADT refused to create a transport task (often SCTS_ADT_MSG / empty user with JWT-only sessions).',
          'Create a new task in ABAP Development Tools: Transport Organizer → open the request → add task.',
          'Or create a new Workbench request (includes an initial task): npm run btp:transport-request -- "your description"',
        ].join(' '),
      );
    }
    throw error;
  }

  return parseTaskCreationPayload(String(response.data));
}

export async function resolveTransportTask(connection, {
  transportNumber,
  owner,
  taskNumber = '',
}) {
  if (taskNumber) {
    return {
      taskNumber,
      reused: false,
    };
  }

  const transport = await readTransport(connection, transportNumber);
  const effectiveOwner = owner || transport.owner;
  const modifiableTasks = transport.tasks.filter(
    (task) => task.owner === effectiveOwner && task.status === 'D',
  );

  if (modifiableTasks.length > 0) {
    return {
      transport,
      taskNumber: modifiableTasks.at(-1).number,
      reused: true,
    };
  }

  throw new Error(
    `Transport ${transportNumber} has no modifiable task for ${effectiveOwner}. Add one in ADT Transport Organizer or pass --task <TASK>.`,
  );
}

export async function ensureTransportTask(connection, {
  transportNumber,
  owner,
  taskNumber = '',
}) {
  const resolved = await resolveTransportTask(connection, {
    transportNumber,
    owner,
    taskNumber,
  });

  return {
    transport: resolved.transport,
    taskNumber: resolved.taskNumber,
    reused: resolved.reused,
  };
}
