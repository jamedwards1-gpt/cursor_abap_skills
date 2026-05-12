import { createRequire } from 'node:module';
import path from 'node:path';
import { XMLParser } from 'fast-xml-parser';

const require = createRequire(import.meta.url);
const contentTypesPath = path.resolve('node_modules/@mcp-abap-adt/adt-clients/dist/constants/contentTypes.js');
const { ACCEPT_TRANSPORT } = require(contentTypesPath);

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

function transportUrl(transportNumber) {
  return `/sap/bc/adt/cts/transportrequests/${encodeURIComponent(transportNumber)}`;
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
  const response = await connection.makeAdtRequest({
    url: transportUrl(transportNumber),
    method: 'GET',
    headers: { Accept: ACCEPT_TRANSPORT },
  });

  return parseTransportPayload(String(response.data));
}

export async function createTransportTask(connection, {
  transportNumber,
  owner,
  description,
}) {
  const xml = [
    '<?xml version="1.0" encoding="ASCII"?>',
    '<tm:root xmlns:tm="http://www.sap.com/cts/adt/tm" tm:useraction="newtask">',
  `  <tm:request tm:number="${escapeXml(transportNumber)}">`,
  `    <tm:task tm:owner="${escapeXml(owner)}" tm:desc="${escapeXml(description)}" tm:type="Development/Correction"/>`,
    '  </tm:request>',
    '</tm:root>',
  ].join('\n');

  const response = await connection.makeAdtRequest({
    url: `${transportUrl(transportNumber)}/tasks`,
    method: 'POST',
    data: xml,
    headers: {
      Accept: ACCEPT_TRANSPORT,
      'Content-Type': 'text/plain',
    },
  });

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
