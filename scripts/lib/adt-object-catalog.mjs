/**
 * ADT repository discovery: quick search + package contents (for tooling / transport-ui).
 */
import { XMLParser } from 'fast-xml-parser';
import { AdtClient } from '@mcp-abap-adt/adt-clients';

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  parseAttributeValue: false,
  trimValues: true,
});

function asArray(v) {
  if (v === undefined || v === null) {
    return [];
  }
  return Array.isArray(v) ? v : [v];
}

function readAttrs(node) {
  if (!node || typeof node !== 'object') {
    return { uri: '', name: '', type: '' };
  }
  return {
    uri: String(node['adtcore:uri'] ?? node.uri ?? '').trim(),
    name: String(node['adtcore:name'] ?? node.name ?? '').trim(),
    type: String(node['adtcore:type'] ?? node.type ?? '').trim(),
  };
}

/**
 * Walk parsed quick-search XML and collect objectReference rows.
 */
export function parseQuickSearchXml(xml) {
  const text = String(xml || '');
  const out = [];
  const seen = new Set();

  function pushOne(uri, name, type) {
    const u = String(uri || '').trim();
    const n = String(name || '').trim();
    const t = String(type || '').trim().toUpperCase();
    if (!u && !n) {
      return;
    }
    const key = `${t}|${n}|${u}`;
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    out.push({ uri: u, name: n.toUpperCase(), adtType: t });
  }

  // Self-closing objectReference tags (any namespace prefix)
  const scRe = /<[^>]*:objectReference([^>]*)\/>/gi;
  let m = scRe.exec(text);
  while (m !== null) {
    const attrs = m[1];
    const uri = /adtcore:uri="([^"]*)"/i.exec(attrs)?.[1];
    const name = /adtcore:name="([^"]*)"/i.exec(attrs)?.[1];
    const typ = /adtcore:type="([^"]*)"/i.exec(attrs)?.[1];
    pushOne(uri, name, typ);
    m = scRe.exec(text);
  }

  try {
    const root = parser.parse(text);
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
        const isRef = k === 'adtcore:objectReference' || k.endsWith(':objectReference') || k === 'objectReference';
        if (isRef) {
          for (const item of asArray(v)) {
            if (item && typeof item === 'object') {
              const { uri, name, type } = readAttrs(item);
              pushOne(uri, name, type);
            }
          }
        }
        visit(v);
      }
    }
    visit(root);
  } catch {
    // regex results only
  }

  return out;
}

/**
 * ADT informationsystem quick search → structured hits.
 */
export async function quickSearchObjects(connection, { query, objectType = '', maxResults = 50 } = {}) {
  const q = String(query || '').trim();
  if (!q) {
    return { objects: [], rawBytes: 0 };
  }
  const client = new AdtClient(connection);
  const res = await client.getUtils().searchObjects({
    query: q,
    objectType: objectType ? String(objectType).trim() : undefined,
    maxResults: Math.min(200, Math.max(1, Number(maxResults) || 50)),
  });
  const raw = String(res?.data ?? '');
  const objects = parseQuickSearchXml(raw);
  return { objects, rawBytes: raw.length, rawPreview: raw.slice(0, 8000) };
}

/**
 * Flat package index (optionally with subpackages).
 */
export async function listPackageObjects(connection, packageName, { includeSubpackages = true } = {}) {
  const pkg = String(packageName || '').trim().toUpperCase();
  if (!pkg) {
    return { objects: [] };
  }
  const client = new AdtClient(connection);
  const items = await client.getUtils().getPackageContentsList(pkg, {
    includeSubpackages: Boolean(includeSubpackages),
    includeDescriptions: true,
  });
  const objects = (items || [])
    .filter((item) => item && !item.isPackage)
    .map((item) => ({
      name: String(item.name || '').toUpperCase(),
      adtType: String(item.adtType || '').toUpperCase(),
      description: item.description ? String(item.description) : '',
      packageName: item.packageName ? String(item.packageName).toUpperCase() : pkg,
      uri: '',
    }));
  return { objects, packageName: pkg };
}

function parseTransportInboxRegex(chunk) {
  const rows = [];
  const re = /<tm:request\b([\s\S]*?)(?:\/>|>)/gi;
  let m = re.exec(chunk);
  while (m !== null) {
    const a = m[1];
    const number = /tm:number="([^"]*)"/i.exec(a)?.[1]?.trim().toUpperCase();
    const description = /tm:desc="([^"]*)"/i.exec(a)?.[1] ?? '';
    const status = /tm:status="([^"]*)"/i.exec(a)?.[1] ?? '';
    const statusText = /tm:status_text="([^"]*)"/i.exec(a)?.[1] ?? '';
    const owner = /tm:owner="([^"]*)"/i.exec(a)?.[1]?.trim().toUpperCase() ?? '';
    if (number) {
      rows.push({ number, description, status, statusText, owner });
    }
    m = re.exec(chunk);
  }
  return rows;
}

function parseTransportInboxByNumberScan(chunk) {
  const seen = new Set();
  const rows = [];
  const re = /tm:number="([^"]+)"/gi;
  let m = re.exec(chunk);
  while (m !== null) {
    const number = m[1].trim().toUpperCase();
    if (number && /^[A-Z]\d{2}K\d{6}$/.test(number) && !seen.has(number)) {
      seen.add(number);
      rows.push({ number, description: '', status: '', statusText: '', owner: '' });
    }
    m = re.exec(chunk);
  }
  return rows;
}

function parseTransportInboxTree(chunk) {
  const rows = [];
  try {
    const root = parser.parse(chunk);
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
        const isReq = k === 'tm:request' || k === 'request' || k.endsWith(':request');
        if (isReq) {
          for (const item of asArray(v)) {
            if (!item || typeof item !== 'object') {
              continue;
            }
            const number = String(item['tm:number'] ?? item.number ?? '').trim().toUpperCase();
            if (!number) {
              continue;
            }
            rows.push({
              number,
              description: String(item['tm:desc'] ?? item.desc ?? '').trim(),
              status: String(item['tm:status'] ?? item.status ?? '').trim(),
              statusText: String(item['tm:status_text'] ?? item.status_text ?? '').trim(),
              owner: String(item['tm:owner'] ?? item.owner ?? '').trim().toUpperCase(),
            });
          }
        }
        visit(v);
      }
    }
    visit(root);
  } catch {
    return [];
  }
  const seen = new Set();
  return rows.filter((r) => {
    if (seen.has(r.number)) {
      return false;
    }
    seen.add(r.number);
    return true;
  });
}

/**
 * Parse ADT GET /cts/transportrequests list XML (best-effort, Steampunk + variants).
 */
export function parseTransportInboxXml(xml) {
  const chunk = String(xml || '');
  let strategy = 'regex';
  let rows = parseTransportInboxRegex(chunk);
  if (rows.length) {
    return { rows, strategy };
  }
  strategy = 'tree';
  rows = parseTransportInboxTree(chunk);
  if (rows.length) {
    return { rows, strategy };
  }
  strategy = 'tm-number-scan';
  rows = parseTransportInboxByNumberScan(chunk);
  return { rows, strategy };
}

/**
 * List transport requests for a user (Workbench / CTS inbox subset).
 */
export async function listOpenTransports(connection, { user, status = '' } = {}) {
  const u = String(user || '').trim();
  if (!u) {
    return { rows: [], rawBytes: 0, rawPreview: '', error: 'user required', parseStrategy: null };
  }
  const client = new AdtClient(connection);
  const out = await client.getRequest().list({
    user: u,
    status: status ? String(status) : undefined,
  });
  const raw = String(out?.listResult?.data ?? '');
  const { rows, strategy } = parseTransportInboxXml(raw);
  return {
    user: u,
    rows,
    rawBytes: raw.length,
    rawPreview: raw.slice(0, 14000),
    parseStrategy: strategy,
  };
}
