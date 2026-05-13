import { AdtClient, getSystemInformation } from '@mcp-abap-adt/adt-clients';
import {
  normalizeTransportListStatus,
  resolveTransportListUser,
  resolveTransportOwner,
} from './adt-session.mjs';
import { listOpenTransports } from './adt-object-catalog.mjs';
import { resolveTransportTask } from './adt-transport.mjs';

/**
 * Use CTS inbox (same source as transport-ui) to find a request with a modifiable task for this user,
 * or create a Workbench request when the inbox is empty.
 */
export async function pickModifiableTransportNumber(connection, env, ownerCli = '') {
  let { user, source } = resolveTransportListUser('', env);
  if (!user) {
    const sys = await getSystemInformation(connection);
    const fromSys = String(sys?.userName || '').trim();
    if (fromSys) {
      user = fromSys;
      source = 'adt_systeminformation';
    }
  }
  if (!user) {
    throw new Error(
      'Cannot pick a transport: no SAP user for the inbox. Set SAP_USERNAME or BTP_ADT_TRANSPORT_OWNER in .secrets/btp-abap.env, or ensure ADT systeminformation returns userName.',
    );
  }

  const ownerForTask = (
    ownerCli ||
    process.env.BTP_ADT_TRANSPORT_OWNER ||
    env?.BTP_ADT_TRANSPORT_OWNER ||
    resolveTransportOwner(env) ||
    ''
  ).trim() || undefined;

  const statusPrimary = normalizeTransportListStatus(process.env.BTP_ADT_LIST_STATUS || 'D');
  let inbox = await listOpenTransports(connection, { user, status: statusPrimary });
  if (inbox.error) {
    throw new Error(`Transport list failed: ${inbox.error}`);
  }

  let candidates = (inbox.rows || []).filter((r) => r?.number).slice(0, 50);
  if (!candidates.length && statusPrimary) {
    inbox = await listOpenTransports(connection, { user, status: undefined });
    if (!inbox.error) {
      candidates = (inbox.rows || []).filter((r) => r?.number).slice(0, 50);
    }
  }

  if (!candidates.length) {
    const owner = (ownerForTask || user || '').trim();
    if (!owner) {
      throw new Error('Cannot create transport: no SAP owner resolved.');
    }
    console.warn(
      `--auto-transport: CTS inbox has no requests (${inbox.rawBytes} bytes from ADT). Creating Workbench request for ${owner}...`,
    );
    const client = new AdtClient(connection);
    const state = await client.getRequest().create({
      description: process.env.BTP_ADT_AUTO_TR_DESC || 'Cursor ADT push (auto transport)',
      transportType: 'workbench',
      owner,
    });
    const transportNumber = String(
      state.transportNumber
        || state.createResult?.data?.transport_request
        || state.createResult?.data?.transport_number
        || '',
    )
      .trim()
      .toUpperCase();
    if (!transportNumber) {
      throw new Error(
        'Workbench transport create did not return a request number. Create a request in ADT and set BTP_ADT_TRANSPORT.',
      );
    }
    console.log(`--auto-transport: created Workbench request ${transportNumber} for ${owner}.`);
    return transportNumber;
  }

  for (const row of candidates) {
    try {
      const resolved = await resolveTransportTask(connection, {
        transportNumber: row.number,
        owner: ownerForTask,
      });
      console.log(
        `--auto-transport: using request ${row.number} (task ${resolved.taskNumber}; inbox user ${user} from ${source}).`,
      );
      return String(row.number).toUpperCase();
    } catch {
      // try next request
    }
  }

  throw new Error(
    `No modifiable transport task found after checking ${candidates.length} inbox request(s). `
      + 'Add a task in ADT Transport Organizer or set BTP_ADT_TRANSPORT explicitly.',
  );
}
