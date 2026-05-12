import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession } from '../../scripts/lib/adt-session.mjs';

function asText(data) {
  if (typeof data === 'string') {
    return data;
  }

  if (Buffer.isBuffer(data)) {
    return data.toString('utf8');
  }

  return JSON.stringify(data);
}

function summarizeSource(source) {
  const text = asText(source).trim();
  const lines = text ? text.split('\n').length : 0;
  const isShell = lines <= 20 && /ENDCLASS\./.test(text) && !/METHOD\s+/i.test(text);
  return {
    lines,
    isShell,
    preview: text.split('\n').slice(0, 8).join('\n'),
  };
}

async function readClassSummary(client, className) {
  const state = await client.getClass().read({ className }, 'active');
  const summary = summarizeSource(state?.readResult?.data);
  return {
    name: className,
    adtType: 'CLAS/OC',
    ...summary,
  };
}

async function readViewSummary(client, viewName) {
  const state = await client.getView().read({ viewName }, 'active');
  const summary = summarizeSource(state?.readResult?.data);
  return {
    name: viewName,
    adtType: 'DDLS/DF',
    ...summary,
  };
}

async function readTableSummary(client, tableName) {
  const state = await client.getTable().read({ tableName }, 'active');
  const summary = summarizeSource(state?.readResult?.data);
  return {
    name: tableName,
    adtType: 'TABL/DT',
    ...summary,
  };
}

export async function loadSteampunkSnapshot(config = {}) {
  const session = await connectAdtSession(loadAdtSession(config.envPath));
  const client = new AdtClient(session.connection);
  const utils = client.getUtils();
  const packageItems = await utils.getPackageContentsList(config.packageName, {
    includeSubpackages: true,
    includeDescriptions: true,
  });

  const objects = packageItems.filter((item) => !item.isPackage);
  const classNames = [
    'ZCL_PARCEL_QAD_QUERY',
    'ZCL_PARCEL_QAD_BG_JOB',
    'ZCL_PARCEL_POLL_UI_HTTP',
    'ZCL_PARCEL_QAD_POLL',
    'ZCL_PARCEL_QAD_DISCOVER',
    'ZCX_PARCEL_QAD_ERROR',
  ];

  const classes = [];
  for (const className of classNames) {
    classes.push(await readClassSummary(client, className));
  }

  const view = await readViewSummary(client, 'ZI_PARCEL_POLL_LOG');
  const pollLogTable = await readTableSummary(client, 'ZPARCEL_POLL_LOG');

  const readyForPolling = classes.every((entry) => !entry.isShell)
    && !pollLogTable.isShell
    && !view.isShell;

  const warnings = [];
  if (objects.some((item) => item.name === 'ZCL_PARCEL_QAD_SCHEDULE')) {
    warnings.push({
      code: 'LEGACY_SCHEDULE_CLASS',
      text: 'Package still contains ZCL_PARCEL_QAD_SCHEDULE on steampunk. Delete it in ADT after Application Jobs use ZCL_PARCEL_QAD_BG_JOB.',
    });
  }

  return {
    checkedAt: new Date().toISOString(),
    localDashboardPort: config.port,
    system: new URL(session.env.SAP_URL).host,
    client: session.env.SAP_CLIENT || '100',
    packageName: config.packageName,
    transportRequest: config.transportRequest,
    transportTask: config.transportTask,
    objectCount: objects.length,
    objects: objects
      .map((item) => ({
        name: item.name,
        adtType: item.adtType,
        description: item.description,
        packageName: item.packageName,
      }))
      .sort((a, b) => {
        const byType = a.adtType.localeCompare(b.adtType);
        if (byType !== 0) {
          return byType;
        }
        return a.name.localeCompare(b.name);
      }),
    classes,
    view,
    pollLogTable,
    readyForPolling,
    warnings,
    httpUiClass: 'ZCL_PARCEL_POLL_UI_HTTP',
    bgJobClass: 'ZCL_PARCEL_QAD_BG_JOB',
    pollLogRows: [],
    pollLogNote: readyForPolling
      ? 'Core classes and CDS are active. Use ZCL_PARCEL_QAD_POLL (ADT), Application Job ZCL_PARCEL_QAD_BG_JOB, or the published HTTP handler ZCL_PARCEL_POLL_UI_HTTP for a browser UI with poll/discover actions.'
      : 'One or more ZPARCEL classes still look like empty shells on steampunk. Run npm run btp:push-parcel from the repo (with transport env vars), then refresh.',
    demoSteps: [
      'This page (port 4010) only reads steampunk via ADT; it does not run polls itself.',
      'In ADT: Application Job template → handler class ZCL_PARCEL_QAD_BG_JOB (replaces old ZCL_PARCEL_QAD_SCHEDULE).',
      'In ADT: Communication scenario / inbound HTTP service → class ZCL_PARCEL_POLL_UI_HTTP → publish → open URL for list + buttons.',
      'Quick test: run ZCL_PARCEL_QAD_POLL with F9, then refresh this dashboard.',
      'Data: ZPARCEL_POLL_LOG table or CDS ZI_PARCEL_POLL_LOG in ADT data preview.',
    ],
  };
}
