import fs from 'node:fs';
import path from 'node:path';
import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession } from './lib/adt-session.mjs';
import { resolveTransportTask } from './lib/adt-transport.mjs';

const tableName = (process.argv[2] || '').toUpperCase();
const sourcePath = process.argv[3] ? path.resolve(process.argv[3]) : null;
const packageName = (process.argv[4] || process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase();
const transportRequest = process.env.BTP_ADT_TRANSPORT || '';
const taskNumber = process.env.BTP_ADT_TASK || '';

if (!tableName || !sourcePath || !transportRequest) {
  console.error(
    'Usage: BTP_ADT_TRANSPORT=<REQUEST> node scripts/push-abap-table.mjs <TABLE> <SOURCE_FILE> [PACKAGE]',
  );
  process.exit(1);
}

if (!fs.existsSync(sourcePath)) {
  console.error(`Source file not found: ${sourcePath}`);
  process.exit(1);
}

const ddlCode = fs.readFileSync(sourcePath, 'utf8');
const session = await connectAdtSession(loadAdtSession());
const client = new AdtClient(session.connection);
const resolved = await resolveTransportTask(session.connection, {
  transportNumber: transportRequest,
  taskNumber,
});
const corrNr = resolved.taskNumber;

let tableExists = false;
try {
  await client.getTable().readMetadata({ tableName });
  tableExists = true;
} catch {
  tableExists = false;
}

if (!tableExists) {
  await client.getTable().create(
    {
      tableName,
      packageName,
      transportRequest: corrNr,
      ddlCode,
    },
    {
      sourceCode: ddlCode,
    },
  );
  console.log(`Created table shell ${tableName} on task ${corrNr}.`);
}

await client.getTable().update(
  {
    tableName,
    transportRequest: corrNr,
    ddlCode,
  },
  {
    sourceCode: ddlCode,
    activateOnUpdate: true,
  },
);

console.log(`Updated and activated table ${tableName} in ${packageName} on task ${corrNr}.`);
