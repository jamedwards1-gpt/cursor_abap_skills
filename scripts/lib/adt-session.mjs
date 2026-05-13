import fs from 'node:fs';
import path from 'node:path';
import { createAbapConnection } from '@mcp-abap-adt/connection';

export function readEnv(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }

  const env = {};
  for (const line of fs.readFileSync(filePath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const separator = trimmed.indexOf('=');
    if (separator === -1) {
      continue;
    }

    env[trimmed.slice(0, separator).trim()] = trimmed.slice(separator + 1).trim();
  }

  return env;
}

export function loadAdtSession(envPath = process.env.BTP_ADT_ENV || '.secrets/btp-abap.env') {
  const resolvedPath = path.resolve(envPath);
  const env = readEnv(resolvedPath);

  if (!env?.SAP_URL || !env?.SAP_JWT_TOKEN) {
    throw new Error(
      `Missing ADT session at ${resolvedPath}. Run: npm run btp:auth -- --key .secrets/service-key.json`,
    );
  }

  const connection = createAbapConnection({
    url: env.SAP_URL,
    client: env.SAP_CLIENT || '100',
    authType: env.SAP_AUTH_TYPE || 'jwt',
    jwtToken: env.SAP_JWT_TOKEN,
  });

  return { connection, env, envPath: resolvedPath };
}

export function resolveTransportOwner(env, fallback = '') {
  if (process.env.BTP_ADT_TRANSPORT_OWNER) {
    return process.env.BTP_ADT_TRANSPORT_OWNER;
  }

  if (env?.BTP_ADT_TRANSPORT_OWNER) {
    return env.BTP_ADT_TRANSPORT_OWNER;
  }

  if (env?.SAP_USERNAME) {
    return env.SAP_USERNAME;
  }

  const token = env?.SAP_JWT_TOKEN;
  if (!token) {
    return fallback;
  }

  try {
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
    const candidate = payload.user_name || payload.user_id || fallback;
    if (/^[A-Z]{2}\d{10}$/.test(candidate)) {
      return candidate;
    }
    return fallback;
  } catch {
    return fallback;
  }
}

/**
 * Human-facing identity for UIs — derived from env / JWT claims only (never returns the raw token).
 * Note: this is whatever the service key / XSUAA JWT encodes, not an Eclipse browser SSO session.
 */
export function describeJwtIdentity(env) {
  const authNote =
    'Auth is the JWT in your server .env (npm run btp:auth) — not the Eclipse embedded browser login.';
  if (!env) {
    return {
      displayUser: '',
      displaySource: '',
      sapUsernameFromEnv: null,
      jwtUserName: null,
      jwtUserId: null,
      jwtEmail: null,
      jwtSub: null,
      transportOwnerHint: null,
      ctsHint: null,
      authNote,
    };
  }

  let payload = null;
  try {
    const token = env.SAP_JWT_TOKEN;
    if (token && typeof token === 'string' && token.split('.').length >= 2) {
      payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
    }
  } catch {
    payload = null;
  }

  const jwtUserName = payload?.user_name ? String(payload.user_name).trim() : null;
  const jwtUserId = payload?.user_id ? String(payload.user_id).trim() : null;
  const jwtSub = payload?.sub ? String(payload.sub).trim() : null;
  const jwtEmail = payload?.email ? String(payload.email).trim() : null;

  const sapUsernameFromEnv = env.SAP_USERNAME ? String(env.SAP_USERNAME).trim() : null;
  const ownerOverride = process.env.BTP_ADT_TRANSPORT_OWNER?.trim() || null;
  const transportOwnerHint = resolveTransportOwner(env) || null;

  let displayUser = '';
  let displaySource = '';
  if (ownerOverride) {
    displayUser = ownerOverride;
    displaySource = 'BTP_ADT_TRANSPORT_OWNER';
  } else if (sapUsernameFromEnv) {
    displayUser = sapUsernameFromEnv;
    displaySource = 'SAP_USERNAME (.env)';
  } else if (jwtUserName) {
    displayUser = jwtUserName;
    displaySource = 'JWT user_name';
  } else if (jwtUserId) {
    displayUser = jwtUserId;
    displaySource = 'JWT user_id';
  } else if (jwtSub) {
    displayUser = jwtSub;
    displaySource = 'JWT sub';
  } else if (transportOwnerHint) {
    displayUser = transportOwnerHint;
    displaySource = 'JWT (BTP-style user id for transports)';
  }

  let ctsHint = null;
  if (!transportOwnerHint && !sapUsernameFromEnv && !ownerOverride) {
    const looksLikeEmail = (s) => typeof s === 'string' && s.includes('@');
    if (looksLikeEmail(jwtUserName) || (jwtUserName && !/^[A-Z]{2}\d{10}$/i.test(jwtUserName))) {
      ctsHint =
        'CTS transport list and many ADT transport calls need your BTP ABAP user id (e.g. CB9980000010), not an email. '
        + 'Add SAP_USERNAME=CB… or BTP_ADT_TRANSPORT_OWNER=CB… to the same .env file as SAP_JWT_TOKEN, then reload config.';
    } else if (!jwtUserName && !jwtUserId) {
      ctsHint = 'No BTP-style user id found in JWT. Set SAP_USERNAME in .secrets/btp-abap.env for transport features.';
    }
  }

  return {
    displayUser,
    displaySource,
    sapUsernameFromEnv,
    jwtUserName,
    jwtUserId,
    jwtSub,
    jwtEmail,
    transportOwnerHint,
    ctsHint,
    authNote,
  };
}

/**
 * SAP user for ADT CTS list APIs. Short/partial query values are treated as mistakes
 * and replaced with {@link resolveTransportOwner} when available.
 */
export function resolveTransportListUser(queryUser, env) {
  const q = String(queryUser || '').trim();
  const fallback = resolveTransportOwner(env) || '';

  if (!q) {
    return { user: fallback, source: fallback ? 'env' : '', ignoredQuery: null };
  }

  const looksBtpUser = (s) => /^[A-Z]{2}\d{10}$/i.test(String(s || '').trim());

  if (looksBtpUser(q)) {
    return { user: q.toUpperCase(), source: 'query', ignoredQuery: null };
  }

  if (fallback && (q.length < 8 || !looksBtpUser(q))) {
    return {
      user: fallback,
      source: 'env_overrode_query',
      ignoredQuery: q,
    };
  }

  return { user: q.toUpperCase(), source: 'query', ignoredQuery: null };
}

/**
 * ADT transport list `status` query param is usually a single letter (e.g. D).
 * Ignore values that look like SAP user ids or transport numbers so the list is not empty by mistake.
 */
export function normalizeTransportListStatus(raw) {
  const s = String(raw || '').trim();
  if (!s) {
    return undefined;
  }
  const u = s.toUpperCase();
  if (u.length <= 2 && /^[A-Z*?]{1,2}$/i.test(u)) {
    return u.toUpperCase();
  }
  if (/^(MODIFIABLE|RELEASED|LOCKED|ALL)$/i.test(s)) {
    return u;
  }
  if (/^[A-Z]{2}\d{8,12}$/i.test(u)) {
    return undefined;
  }
  if (/^[A-Z]\d{2}K\d{6}$/i.test(u)) {
    return undefined;
  }
  return undefined;
}

export async function connectAdtSession(session) {
  await session.connection.connect();
  return session;
}
