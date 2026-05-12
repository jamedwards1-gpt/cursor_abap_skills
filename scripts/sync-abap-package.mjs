import fs from 'node:fs';
import path from 'node:path';
import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession } from './lib/adt-session.mjs';

const packageName = (process.argv[2] || 'ZZSD').toUpperCase();
const outputRoot = path.resolve('btp-content/abap', packageName);

const extensionByType = {
  'CLAS/OC': '.clas.abap',
  'INTF/IF': '.intf.abap',
  'INTF/OI': '.intf.abap',
  'PROG/P': '.prog.abap',
  'DDLS/DF': '.asddls',
  'DDLX/EX': '.ddlxs',
  'BDEF/BDO': '.asbdef',
  'SRVD/SRV': '.srvd',
  'TABL/DT': '.tabl.abap',
  'TABL/DS': '.tabl.abap',
  'STRU/DT': '.stru.abap',
  'TTYP/DF': '.ttyp.abap',
  'DOMA/DD': '.doma.xml',
  'DTEL/DE': '.dtel.xml',
  'FUGR/FF': '.func.abap',
};

function sanitizeSegment(value) {
  return value.replace(/[^A-Za-z0-9._-]+/g, '_');
}

function targetPath(item) {
  const typeDir = sanitizeSegment(item.adtType || 'unknown');
  const extension = extensionByType[item.adtType] || '.abap';
  const fileName = `${sanitizeSegment(item.name)}${extension}`;
  return path.join(outputRoot, typeDir, fileName);
}

function asText(data) {
  if (typeof data === 'string') {
    return data;
  }

  if (Buffer.isBuffer(data)) {
    return data.toString('utf8');
  }

  return JSON.stringify(data, null, 2);
}

const session = await connectAdtSession(loadAdtSession());
const client = new AdtClient(session.connection);
const utils = client.getUtils();

const items = await utils.getPackageContentsList(packageName, {
  includeSubpackages: true,
  includeDescriptions: true,
});

const objects = items.filter((item) => !item.isPackage);
fs.mkdirSync(outputRoot, { recursive: true });

const manifest = {
  syncedAt: new Date().toISOString(),
  packageName,
  objectCount: objects.length,
  objects: [],
  failures: [],
};

for (const item of objects) {
  const destination = targetPath(item);
  fs.mkdirSync(path.dirname(destination), { recursive: true });

  const entry = {
    name: item.name,
    adtType: item.adtType,
    description: item.description,
    packageName: item.packageName,
    path: path.relative(process.cwd(), destination),
    status: 'pending',
  };

  try {
    const source = await utils.readObjectSource(item.adtType, item.name);
    fs.writeFileSync(destination, asText(source.data));
    entry.status = 'source';
  } catch (sourceError) {
    try {
      const metadata = await utils.readObjectMetadata(item.adtType, item.name);
      const metadataPath = destination.replace(/\.[^.]+$/, '.metadata.xml');
      fs.writeFileSync(metadataPath, asText(metadata.data));
      entry.path = path.relative(process.cwd(), metadataPath);
      entry.status = 'metadata';
    } catch (metadataError) {
      entry.status = 'skipped';
      manifest.failures.push({
        name: item.name,
        adtType: item.adtType,
        sourceError: sourceError.message,
        metadataError: metadataError.message,
      });
    }
  }

  manifest.objects.push(entry);
}

const manifestPath = path.join(outputRoot, 'manifest.json');
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

const synced = manifest.objects.filter((entry) => entry.status !== 'skipped').length;
console.log(`Synced ${synced}/${manifest.objectCount} objects from ${packageName} into ${outputRoot}`);
console.log(`Manifest: ${manifestPath}`);

if (manifest.failures.length > 0) {
  console.log(`Skipped ${manifest.failures.length} objects without readable source or metadata.`);
}
