import fs from 'node:fs';
import path from 'node:path';
import { createAbapConnection } from '@mcp-abap-adt/connection';

const envPath = path.resolve(
  process.env.BTP_ADT_ENV || '.secrets/btp-abap.env',
);

function readEnv(filePath) {
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

function redactUrl(url) {
  try {
    const parsed = new URL(url);
    return `${parsed.protocol}//${parsed.host}`;
  } catch {
    return '[invalid-url]';
  }
}

const env = readEnv(envPath);
if (!env?.SAP_URL || !env?.SAP_JWT_TOKEN) {
  console.error(
    `Missing ADT session at ${envPath}. Run: npm run btp:auth -- --key .secrets/service-key.json`,
  );
  process.exit(1);
}

const connection = createAbapConnection({
  url: env.SAP_URL,
  client: env.SAP_CLIENT || '100',
  authType: env.SAP_AUTH_TYPE || 'jwt',
  jwtToken: env.SAP_JWT_TOKEN,
});

await connection.connect();

const response = await connection.makeAdtRequest({
  method: 'GET',
  url: '/sap/bc/adt/discovery',
});

const outputDir = path.resolve('btp-content');
fs.mkdirSync(outputDir, { recursive: true });

const body = typeof response.data === 'string'
  ? response.data
  : JSON.stringify(response.data, null, 2);

const outputPath = path.join(outputDir, 'adt-discovery.xml');
fs.writeFileSync(outputPath, body);

const summaryPath = path.join(outputDir, 'connection-summary.json');
fs.writeFileSync(
  summaryPath,
  `${JSON.stringify({
    checkedAt: new Date().toISOString(),
    system: redactUrl(env.SAP_URL),
    client: env.SAP_CLIENT || '100',
    discoveryBytes: Buffer.byteLength(body, 'utf8'),
    discoveryFile: outputPath,
  }, null, 2)}\n`,
);

console.log(`ADT discovery saved to ${outputPath}`);
console.log(`Connection summary saved to ${summaryPath}`);
