import path from 'node:path';
import { spawn } from 'node:child_process';

const transport = process.env.BTP_ADT_TRANSPORT;
const task = process.env.BTP_ADT_TASK;
const extraArgs = process.argv.slice(2);

if (!transport) {
  console.error('Set BTP_ADT_TRANSPORT to the existing request number before running btp:push-qad.');
  process.exit(1);
}

const classes = [
  ['ZCL_QAD_QUERYSHIPMENT_SVC', 'btp-content/abap/ZZSD/CLAS_OC/ZCL_QAD_QUERYSHIPMENT_SVC.clas.abap'],
  ['ZCL_BATCH_SCHEDULE_QAD', 'btp-content/abap/ZZSD/CLAS_OC/ZCL_BATCH_SCHEDULE_QAD.clas.abap'],
  ['ZCL_BATCH_POLL_QAD_STATUS', 'btp-content/abap/ZZSD/CLAS_OC/ZCL_BATCH_POLL_QAD_STATUS.clas.abap'],
  ['ZCL_BATCH_QAD_QUERY_RUNNER', 'btp-content/abap/ZZSD/CLAS_OC/ZCL_BATCH_QAD_QUERY_RUNNER.clas.abap'],
];

function runPush(className, sourcePath) {
  const scriptPath = path.resolve('scripts/push-abap-class.mjs');
  const args = [
    scriptPath,
    className,
    sourcePath,
    '--transport',
    transport,
    ...(task ? ['--task', task] : []),
    ...extraArgs,
  ];

  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, args, {
      stdio: 'inherit',
      env: process.env,
    });

    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`Push failed for ${className} with exit code ${code}.`));
    });
  });
}

for (const [className, sourcePath] of classes) {
  await runPush(className, sourcePath);
}

console.log(`Pushed ${classes.length} classes on transport ${transport}${task ? ` task ${task}` : ''}.`);
