/**
 * Build an overview of transport requests for a user: list + per-request metadata + organizer objects.
 */
import { listOpenTransports } from './adt-object-catalog.mjs';
import {
  getTransportOrganizerTreeXml,
  parseTransportAbapObjects,
  readTransport,
} from './adt-transport.mjs';

async function mapPool(items, concurrency, fn) {
  if (!items.length) {
    return [];
  }
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    for (;;) {
      const i = next;
      next += 1;
      if (i >= items.length) {
        return;
      }
      results[i] = await fn(items[i], i);
    }
  }
  const n = Math.min(concurrency, items.length);
  await Promise.all(Array.from({ length: n }, () => worker()));
  return results;
}

function summarizeOrganizer({ status, xml, flavor, message }) {
  const objs = parseTransportAbapObjects(xml);
  return {
    httpStatus: status,
    flavor: flavor || 'v1',
    note: message || null,
    xmlBytes: xml.length,
    objectCount: objs.length,
    abapObjects: objs,
  };
}

/**
 * @param {object} connection
 * @param {object} opts
 * @param {string} opts.user
 * @param {string} [opts.status]
 * @param {number} [opts.maxRequests=50]
 * @param {number} [opts.concurrency=4]
 * @param {boolean} [opts.includeOrganizer=true]
 * @param {boolean} [opts.includeTaskOrganizers=false] - extra GET per task (slow)
 */
export async function buildTransportOverview(connection, {
  user,
  status,
  maxRequests = 50,
  concurrency = 4,
  includeOrganizer = true,
  includeTaskOrganizers = false,
}) {
  const list = await listOpenTransports(connection, { user, status });
  if (list.error) {
    return { error: list.error, user: list.user, requests: [] };
  }

  const cap = Math.min(120, Math.max(1, Number(maxRequests) || 50));
  const seen = new Set();
  const rows = (list.rows || []).filter((r) => {
    if (!r?.number || seen.has(r.number)) {
      return false;
    }
    seen.add(r.number);
    return true;
  }).slice(0, cap);

  const requests = await mapPool(rows, concurrency, async (row) => {
    const number = row.number;
    const entry = {
      number,
      listDescription: row.description,
      listStatus: row.status,
      listStatusText: row.statusText,
      transport: null,
      organizer: null,
      taskOrganizers: null,
      error: null,
    };
    try {
      entry.transport = await readTransport(connection, number);
      if (includeOrganizer) {
        const orgXml = await getTransportOrganizerTreeXml(connection, number);
        entry.organizer = summarizeOrganizer(orgXml);
      }
      if (includeTaskOrganizers && entry.transport?.tasks?.length) {
        entry.taskOrganizers = await mapPool(entry.transport.tasks, 3, async (task) => {
          try {
            const ox = await getTransportOrganizerTreeXml(connection, task.number);
            return {
              taskNumber: task.number,
              ...summarizeOrganizer(ox),
            };
          } catch (e) {
            return {
              taskNumber: task.number,
              error: e?.message || String(e),
              objectCount: 0,
              abapObjects: [],
            };
          }
        });
      }
    } catch (e) {
      entry.error = e?.message || String(e);
    }
    return entry;
  });

  return {
    user: list.user,
    listRawBytes: list.rawBytes,
    listParseStrategy: list.parseStrategy || null,
    listRawPreviewSnippet: (list.rows || []).length === 0 ? (list.rawPreview || '').slice(0, 6000) : null,
    maxRequests: cap,
    listed: (list.rows || []).length,
    fetched: requests.length,
    requests,
  };
}
