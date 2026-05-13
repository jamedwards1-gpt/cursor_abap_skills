import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { XMLParser } from 'fast-xml-parser';

const require = createRequire(import.meta.url);
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const contentTypesPath = path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/constants/contentTypes.js');
const internalUtilsPath = path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/utils/internalUtils.js');
const unlockPath = path.join(repoRoot, 'node_modules/@mcp-abap-adt/adt-clients/dist/core/class/unlock.js');
const { ACCEPT_LOCK } = require(contentTypesPath);
const { encodeSapObjectName } = require(internalUtilsPath);
const { unlockClass } = require(unlockPath);

const lockParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
});

/**
 * Lock a class for MODIFY. On some BTP ABAP systems, locking with a transport *task* number returns
 * `IS_LOCAL=X` and an empty `CORRNR`, so changes are not recorded on the transport (Transport Organizer stays empty).
 * If `transportRequestNumber` is set and differs from `corrNr`, we unlock and retry once with the parent *request* number.
 *
 * @param {string} [transportRequestNumber] - Parent CTS request (e.g. H01K900034) when corrNr is a task (e.g. H01K900035).
 */
export async function lockClassForTransport(connection, className, corrNr, { transportRequestNumber } = {}) {
  const encodedName = encodeSapObjectName(className).toLowerCase();
  const lockUrl = (nr) =>
    `/sap/bc/adt/oo/classes/${encodedName}?_action=LOCK&accessMode=MODIFY&corrNr=${encodeURIComponent(nr)}`;

  async function lockOnce(nr) {
    const response = await connection.makeAdtRequest({
      url: lockUrl(nr),
      method: 'POST',
      data: null,
      headers: { Accept: ACCEPT_LOCK },
    });
    const result = lockParser.parse(response.data);
    const data = result?.['asx:abap']?.['asx:values']?.DATA;
    return { data, response };
  }

  let { data } = await lockOnce(corrNr);
  let lockHandle = data?.LOCK_HANDLE;
  let assignedCorrNr = data?.CORRNR;
  const isLocalOnly =
    data?.IS_LOCAL === 'X' &&
    (!assignedCorrNr || String(assignedCorrNr).trim() === '') &&
    transportRequestNumber &&
    String(transportRequestNumber).toUpperCase() !== String(corrNr).toUpperCase();

  if (isLocalOnly && lockHandle) {
    await unlockClass(connection, className, lockHandle);
    lockHandle = undefined;
    console.warn(
      `[adt] Lock with task ${corrNr} was local-only (no CORRNR). Retrying lock with transport request ${transportRequestNumber}.`,
    );
    ({ data } = await lockOnce(transportRequestNumber));
    lockHandle = data?.LOCK_HANDLE;
    assignedCorrNr = data?.CORRNR;
  }

  if (!lockHandle) {
    throw new Error(`Failed to lock ${className} on transport ${corrNr}.`);
  }

  return {
    lockHandle,
    corrNr: (assignedCorrNr && String(assignedCorrNr).trim()) || transportRequestNumber || corrNr,
  };
}
