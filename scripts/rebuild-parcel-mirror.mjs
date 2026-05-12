import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('btp-content/abap');
const replacements = [
  ['ZCL_QAD_QUERYSHIPMENT_SVC', 'ZCL_PARCEL_QAD_QUERY'],
  ['zcl_qad_queryshipment_svc', 'zcl_parcel_qad_query'],
  ['ZCL_BATCH_SCHEDULE_QAD', 'ZCL_PARCEL_QAD_BG_JOB'],
  ['zcl_batch_schedule_qad', 'zcl_parcel_qad_bg_job'],
  ['ZCL_BATCH_POLL_QAD_STATUS', 'ZCL_PARCEL_QAD_POLL'],
  ['zcl_batch_poll_qad_status', 'zcl_parcel_qad_poll'],
  ['ZCL_BATCH_QAD_QUERY_RUNNER', 'ZCL_PARCEL_QAD_DISCOVER'],
  ['zcl_batch_qad_query_runner', 'zcl_parcel_qad_discover'],
  ['ZCX_QAD_SIMPLE_ERROR', 'ZCX_PARCEL_QAD_ERROR'],
  ['zcx_qad_simple_error', 'zcx_parcel_qad_error'],
  ['ZQAD_POLL_LOG', 'ZPARCEL_POLL_LOG'],
  ['zqad_poll_log', 'zparcel_poll_log'],
  [ `object    = 'ZCL_BATCH_SCHEDULE'`, `object    = 'ZPARCEL_QAD'` ],
  [ `subobject = 'POLLING'`, `subobject = 'BGJOB'` ],
];

const files = [
  ['ZZSD/CLAS_OC/ZCL_QAD_QUERYSHIPMENT_SVC.clas.abap', 'ZPARCEL/CLAS_OC/ZCL_PARCEL_QAD_QUERY.clas.abap'],
  ['ZZSD/CLAS_OC/ZCL_BATCH_SCHEDULE_QAD.clas.abap', 'ZPARCEL/CLAS_OC/ZCL_PARCEL_QAD_BG_JOB.clas.abap'],
  ['ZZSD/CLAS_OC/ZCL_BATCH_POLL_QAD_STATUS.clas.abap', 'ZPARCEL/CLAS_OC/ZCL_PARCEL_QAD_POLL.clas.abap'],
  ['ZZSD/CLAS_OC/ZCL_BATCH_QAD_QUERY_RUNNER.clas.abap', 'ZPARCEL/CLAS_OC/ZCL_PARCEL_QAD_DISCOVER.clas.abap'],
  ['ZZSD/CLAS_OC/ZCX_QAD_SIMPLE_ERROR.clas.abap', 'ZPARCEL/CLAS_OC/ZCX_PARCEL_QAD_ERROR.clas.abap'],
];

function transform(source) {
  let output = source;
  for (const [from, to] of replacements) {
    output = output.replaceAll(from, to);
  }
  return output;
}

for (const [sourceRelative, targetRelative] of files) {
  const sourcePath = path.join(root, sourceRelative);
  const targetPath = path.join(root, targetRelative);
  const source = fs.readFileSync(sourcePath, 'utf8');
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, transform(source));
  console.log(`Rebuilt ${targetRelative} from ${sourceRelative}.`);
}
