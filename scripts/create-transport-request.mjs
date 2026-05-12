import { AdtClient } from '@mcp-abap-adt/adt-clients';
import { connectAdtSession, loadAdtSession, resolveTransportOwner } from './lib/adt-session.mjs';

const description = process.argv.slice(2).join(' ').trim() || 'Parcel QAD polling rebuild';

const session = await connectAdtSession(loadAdtSession());
const owner = resolveTransportOwner(session.env);
if (!owner) {
  console.error('Transport owner is required. Set BTP_ADT_TRANSPORT_OWNER or refresh btp:auth.');
  process.exit(1);
}

const client = new AdtClient(session.connection);
const state = await client.getRequest().create({
  description,
  transportType: 'workbench',
  owner,
});

const transportNumber = state.transportNumber
  || state.createResult?.data?.transport_request
  || state.createResult?.data?.transport_number;

if (!transportNumber) {
  console.error('Transport request was created but no request number was returned.');
  process.exit(1);
}

console.log(transportNumber);
