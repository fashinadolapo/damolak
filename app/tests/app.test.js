'use strict';

const request = require('supertest');
const { app, server } = require('../src/index');

afterAll((done) => {
  server.close(done);
});

describe('GET /', () => {
  it('should return 200 with app info', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message');
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('environment');
    expect(res.body).toHaveProperty('hostname');
    expect(res.body).toHaveProperty('timestamp');
  });
});

describe('GET /health', () => {
  it('should return 200 with health status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body).toHaveProperty('uptime_seconds');
    expect(res.body).toHaveProperty('system');
    expect(res.body.system).toHaveProperty('memory');
  });
});

describe('GET /metrics', () => {
  it('should return 200 with process metrics', async () => {
    const res = await request(app).get('/metrics');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('process');
    expect(res.body).toHaveProperty('os');
    expect(res.body).toHaveProperty('timestamp');
  });
});

describe('GET /unknown', () => {
  it('should return 404 for unknown routes', async () => {
    const res = await request(app).get('/unknown-route');
    expect(res.statusCode).toBe(404);
    expect(res.body).toHaveProperty('error', 'Not Found');
  });
});
