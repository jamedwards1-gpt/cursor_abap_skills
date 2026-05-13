#!/usr/bin/env node
/**
 * Frees TRANSPORT_UI_PORT (default 3980) by SIGTERM, then SIGKILL if still listening.
 * Used by npm prestart; run manually: npm run stop
 * Skip: TRANSPORT_UI_NO_PRESTOP=1 npm start
 */
import { execSync } from 'node:child_process';
import { setTimeout } from 'node:timers/promises';

if (process.env.TRANSPORT_UI_NO_PRESTOP === '1') {
  console.log('[transport-ui stop] skipped (TRANSPORT_UI_NO_PRESTOP=1)');
  process.exit(0);
}

const port = String(process.env.TRANSPORT_UI_PORT || '3980');

function pidsListening(p) {
  try {
    const out = execSync(`lsof -tiTCP:${p} -sTCP:LISTEN`, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const ids = out
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .map((x) => Number(x))
      .filter((n) => Number.isFinite(n) && n > 0);
    return [...new Set(ids)];
  } catch {
    return [];
  }
}

function signal(pid, sig) {
  try {
    process.kill(pid, sig);
    return true;
  } catch (e) {
    if (e?.code === 'ESRCH') {
      return false;
    }
    throw e;
  }
}

let pids = pidsListening(port);
if (pids.length === 0) {
  console.log(`[transport-ui stop] port ${port} is free`);
  process.exit(0);
}

console.log(`[transport-ui stop] stopping PID(s) on ${port}: ${pids.join(', ')}`);
for (const pid of pids) {
  signal(pid, 'SIGTERM');
}

await setTimeout(400);
pids = pidsListening(port);
if (pids.length > 0) {
  console.warn(`[transport-ui stop] still listening, SIGKILL: ${pids.join(', ')}`);
  for (const pid of pids) {
    signal(pid, 'SIGKILL');
  }
  await setTimeout(200);
}

const left = pidsListening(port);
if (left.length > 0) {
  console.error(`[transport-ui stop] could not free port ${port} (PIDs: ${left.join(', ')})`);
  process.exit(1);
}

console.log(`[transport-ui stop] port ${port} is free`);
