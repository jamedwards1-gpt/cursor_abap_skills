import express from 'express';
import path from 'node:path';
import config from './config.js';
import { loadSteampunkSnapshot } from './steampunk.js';

const app = express();
let cache = {
  checkedAt: null,
  data: null,
  error: null,
};

async function refreshSnapshot() {
  try {
    const data = await loadSteampunkSnapshot(config);
    cache = {
      checkedAt: data.checkedAt,
      data,
      error: null,
    };
    return data;
  } catch (error) {
    cache = {
      checkedAt: new Date().toISOString(),
      data: null,
      error: error.message || String(error),
    };
    throw error;
  }
}

app.get('/api/health', (_req, res) => {
  res.json({
    ok: !cache.error,
    checkedAt: cache.checkedAt,
    error: cache.error,
  });
});

app.get('/api/status', async (_req, res) => {
  try {
    const data = cache.data && cache.checkedAt
      ? cache.data
      : await refreshSnapshot();
    return res.json({
      ...data,
      localDashboardPort: config.port,
    });
  } catch (error) {
    return res.status(502).json({
      error: error.message || String(error),
      checkedAt: cache.checkedAt,
    });
  }
});

app.post('/api/refresh', async (_req, res) => {
  try {
    const data = await refreshSnapshot();
    return res.json({
      ...data,
      localDashboardPort: config.port,
    });
  } catch (error) {
    return res.status(502).json({
      error: error.message || String(error),
      checkedAt: cache.checkedAt,
    });
  }
});

app.use(express.static(config.publicDir));

app.get('/', (_req, res) => {
  res.sendFile(path.join(config.publicDir, 'index.html'));
});

app.listen(config.port, config.host, () => {
  console.log(`Parcel monitor listening on http://${config.host}:${config.port}`);
  refreshSnapshot().catch((error) => {
    console.error(`Initial steampunk refresh failed: ${error.message || error}`);
  });
});
