import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Request, Response, NextFunction } from 'express';
import { requireAuth, AuthenticatedRequest } from '../src/auth';

vi.mock('../src/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
  },
}));

import { supabase } from '../src/supabase';

function mockReqResNext(headers: Record<string, string> = {}) {
  const req = { headers } as unknown as AuthenticatedRequest;
  const res = {
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
  } as unknown as Response;
  const next = vi.fn() as NextFunction;
  return { req, res, next };
}

describe('requireAuth middleware', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('rejects request without Authorization header', async () => {
    const { req, res, next } = mockReqResNext({});
    await requireAuth(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: expect.stringContaining('Missing') }),
    );
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects request with non-Bearer auth header', async () => {
    const { req, res, next } = mockReqResNext({ authorization: 'Basic abc123' });
    await requireAuth(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects request when Supabase returns error', async () => {
    vi.mocked(supabase.auth.getUser).mockResolvedValue({
      data: { user: null },
      error: { message: 'invalid token' },
    } as any);

    const { req, res, next } = mockReqResNext({ authorization: 'Bearer bad-token' });
    await requireAuth(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('passes with valid token and sets userId', async () => {
    vi.mocked(supabase.auth.getUser).mockResolvedValue({
      data: { user: { id: 'user-123' } },
      error: null,
    } as any);

    const { req, res, next } = mockReqResNext({ authorization: 'Bearer valid-token' });
    await requireAuth(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(req.userId).toBe('user-123');
    expect(res.status).not.toHaveBeenCalled();
  });
});
