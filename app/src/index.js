'use strict';

const express = require('express');
const os = require('os');
const process = require('process');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const APP_ENV = process.env.NODE_ENV || 'production';

app.use(express.json());

// Request logger middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        method: req.method,
        path: req.path,
        status: res.statusCode,
        duration_ms: duration,
        ip: req.ip,
      })
    );
  });
  next();
});

// ── Routes ──────────────────────────────────────────────────────────────────

app.get('/', (req, res) => {
  res.json({
    message: 'DevOps Challenge App — running!',
    version: APP_VERSION,
    environment: APP_ENV,
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (req, res) => {
  const healthData = {
    status: 'healthy',
    version: APP_VERSION,
    environment: APP_ENV,
    uptime_seconds: Math.floor(process.uptime()),
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
    system: {
      platform: os.platform(),
      arch: os.arch(),
      memory: {
        total_mb: Math.round(os.totalmem() / 1024 / 1024),
        free_mb: Math.round(os.freemem() / 1024 / 1024),
        used_percent: Math.round(
          ((os.totalmem() - os.freemem()) / os.totalmem()) * 100
        ),
      },
      load_avg: os.loadavg(),
    },
  };
  res.status(200).json(healthData);
});

app.get('/metrics', (req, res) => {
  const memUsage = process.memoryUsage();
  res.json({
    process: {
      pid: process.pid,
      uptime_seconds: Math.floor(process.uptime()),
      memory: {
        rss_mb: Math.round(memUsage.rss / 1024 / 1024),
        heap_used_mb: Math.round(memUsage.heapUsed / 1024 / 1024),
        heap_total_mb: Math.round(memUsage.heapTotal / 1024 / 1024),
      },
      cpu_usage: process.cpuUsage(),
    },
    os: {
      load_avg_1m: os.loadavg()[0],
      free_memory_mb: Math.round(os.freemem() / 1024 / 1024),
    },
    timestamp: new Date().toISOString(),
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found', path: req.path });
});

// Global error handler
app.use((err, req, res, _next) => {
  console.error(JSON.stringify({ level: 'error', message: err.message, stack: err.stack }));
  res.status(500).json({ error: 'Internal Server Error' });
});

// ── Start ────────────────────────────────────────────────────────────────────

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(
    JSON.stringify({
      level: 'info',
      message: `Server started`,
      port: PORT,
      version: APP_VERSION,
      environment: APP_ENV,
      pid: process.pid,
    })
  );
});

// Graceful shutdown
const shutdown = (signal) => {
  console.log(JSON.stringify({ level: 'info', message: `${signal} received — shutting down` }));
  server.close(() => {
    console.log(JSON.stringify({ level: 'info', message: 'Server closed' }));
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

module.exports = { app, server };
