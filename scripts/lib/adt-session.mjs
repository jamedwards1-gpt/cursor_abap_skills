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

export async function connectAdtSession(session) {
  await session.connection.connect();
  return session;
}
