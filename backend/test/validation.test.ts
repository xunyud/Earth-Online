import { describe, it, expect, vi, beforeAll } from 'vitest';
import request from 'supertest';

vi.mock('../src/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn().mockResolvedValue({
        data: { user: { id: 'user-test' } },
        error: null,
      }),
    },
  },
}));

vi.mock('../src/redis', () => ({
  default: { isOpen: false, rPush: vi.fn() },
}));

vi.mock('../src/processor', () => ({
  processUserMessages: vi.fn(),
}));

vi.mock('../src/llm', () => ({
  freeformChat: vi.fn().mockResolvedValue('mock reply'),
}));

import { app } from '../src/index';

describe('POST /webhook validation', () => {
  const authHeader = 'Bearer valid-token';

  it('rejects missing content', async () => {
    const res = await request(app)
      .post('/webhook')
      .set('Authorization', authHeader)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('content');
  });

  it('rejects non-string content', async () => {
    const res = await request(app)
      .post('/webhook')
      .set('Authorization', authHeader)
      .send({ content: 123 });

    expect(res.status).toBe(400);
  });

  it('rejects content over 10000 chars', async () => {
    const res = await request(app)
      .post('/webhook')
      .set('Authorization', authHeader)
      .send({ content: 'x'.repeat(10001) });

    expect(res.status).toBe(400);
  });

  it('accepts valid content', async () => {
    const res = await request(app)
      .post('/webhook')
      .set('Authorization', authHeader)
      .send({ content: '今天完成了项目文档' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

describe('POST /agent/free-chat validation', () => {
  const authHeader = 'Bearer valid-token';

  it('rejects missing message', async () => {
    const res = await request(app)
      .post('/agent/free-chat')
      .set('Authorization', authHeader)
      .send({ systemPrompt: 'you are a helper' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('message');
  });

  it('rejects message over 5000 chars', async () => {
    const res = await request(app)
      .post('/agent/free-chat')
      .set('Authorization', authHeader)
      .send({ message: 'x'.repeat(5001), systemPrompt: 'test' });

    expect(res.status).toBe(400);
  });

  it('rejects missing systemPrompt', async () => {
    const res = await request(app)
      .post('/agent/free-chat')
      .set('Authorization', authHeader)
      .send({ message: 'hello' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('systemPrompt');
  });

  it('rejects systemPrompt over 2000 chars', async () => {
    const res = await request(app)
      .post('/agent/free-chat')
      .set('Authorization', authHeader)
      .send({ message: 'hello', systemPrompt: 'x'.repeat(2001) });

    expect(res.status).toBe(400);
  });

  it('accepts valid request and returns reply', async () => {
    const res = await request(app)
      .post('/agent/free-chat')
      .set('Authorization', authHeader)
      .send({ message: '你好', systemPrompt: '你是助手' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.reply).toBe('mock reply');
  });
});
