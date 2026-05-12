import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = path.resolve(rootDir, '..');

export default {
  host: process.env.PARCEL_MONITOR_HOST || '127.0.0.1',
  port: Number(process.env.PARCEL_MONITOR_PORT || 4010),
  packageName: (process.env.BTP_ADT_PACKAGE || 'ZPARCEL').toUpperCase(),
  transportRequest: process.env.BTP_ADT_TRANSPORT || 'H01K900032',
  transportTask: process.env.BTP_ADT_TASK || 'H01K900033',
  envPath: process.env.BTP_ADT_ENV || path.join(repoRoot, '.secrets/btp-abap.env'),
  publicDir: path.join(rootDir, 'public'),
};
