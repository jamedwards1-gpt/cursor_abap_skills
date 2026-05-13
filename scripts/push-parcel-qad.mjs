import path from 'node:path';
import { spawn } from 'node:child_process';

const transport = process.env.BTP_ADT_TRANSPORT;
const task = process.env.BTP_ADT_TASK;
const extraArgs = process.argv.slice(2);
const createObjects = extraArgs.includes('--create') || process.env.BTP_ADT_CREATE === '1';
const recreateObjects = extraArgs.includes('--recreate') || process.env.BTP_ADT_RECREATE === '1';

if (!transport) {
  console.error('Set BTP_ADT_TRANSPORT to the parcel transport request before running btp:push-parcel.');
  process.exit(1);
}

const root = 'btp-content/abap/ZPARCEL';
const classes = [
  ['ZCX_PARCEL_QAD_ERROR', `${root}/CLAS_OC/ZCX_PARCEL_QAD_ERROR.clas.abap`],
  ['ZCL_PARCEL_QAD_QUERY', `${root}/CLAS_OC/ZCL_PARCEL_QAD_QUERY.clas.abap`],
  ['ZCL_PARCEL_QAD_BG_JOB', `${root}/CLAS_OC/ZCL_PARCEL_QAD_BG_JOB.clas.abap`],
  ['ZCL_PARCEL_POLL_UI_HTTP', `${root}/CLAS_OC/ZCL_PARCEL_POLL_UI_HTTP.clas.abap`],
  ['ZCL_PARCEL_QAD_POLL', `${root}/CLAS_OC/ZCL_PARCEL_QAD_POLL.clas.abap`],
  ['ZCL_PARCEL_QAD_DISCOVER', `${root}/CLAS_OC/ZCL_PARCEL_QAD_DISCOVER.clas.abap`],
  ['ZCL_PARCEL_QAD_SCHEDULE', `${root}/CLAS_OC/ZCL_PARCEL_QAD_SCHEDULE.clas.abap`],
];

function runNode(scriptPath, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath, ...args], {
      stdio: 'inherit',
      env: process.env,
    });

    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${path.basename(scriptPath)} failed with exit code ${code}.`));
    });
  });
}

function runPush(className, sourcePath) {
  const args = [
    className,
    sourcePath,
    '--transport',
    transport,
    ...(task ? ['--task', task] : []),
    ...(createObjects ? ['--create'] : []),
    ...(recreateObjects ? ['--recreate'] : []),
    ...extraArgs.filter((arg) => arg !== '--create' && arg !== '--recreate'),
  ];

  return runNode(path.resolve('scripts/push-abap-class.mjs'), args);
}

for (const [className, sourcePath] of classes) {
  await runPush(className, sourcePath);
}

const views = [
  ['ZI_PARCEL_POLL_LOG', `${root}/DDLS_DF/ZI_PARCEL_POLL_LOG.asddls`],
];

for (const [viewName, sourcePath] of views) {
  await runNode(path.resolve('scripts/push-abap-ddls.mjs'), [
    viewName,
    sourcePath,
    '--transport',
    transport,
    ...(task ? ['--task', task] : []),
    ...(createObjects ? ['--create'] : []),
  ]);
}

console.log(
  `Pushed ${classes.length} parcel classes and ${views.length} CDS views on transport ${transport}${task ? ` task ${task}` : ''}.`,
);
