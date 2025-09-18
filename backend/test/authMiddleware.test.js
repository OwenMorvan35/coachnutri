import { test, mock } from 'node:test';
import assert from 'node:assert';
import jwt from 'jsonwebtoken';

process.env.JWT_SECRET = 'test-secret';

const { requireAuth } = await import('../src/middleware/auth.js');

const buildResponse = () => {
  const payload = {
    statusCode: null,
    body: null,
  };

  return {
    locals: {},
    status(code) {
      payload.statusCode = code;
      return this;
    },
    json(body) {
      payload.body = body;
      return payload;
    },
    payload,
  };
};

test('requireAuth returns 401 when token is missing', () => {
  const req = { headers: {} };
  const res = buildResponse();
  const next = mock.fn();

  requireAuth(req, res, next);

  assert.strictEqual(res.payload.statusCode, 401);
  assert.strictEqual(next.mock.callCount(), 0);
  assert.strictEqual(res.payload.body.error.code, 'unauthorized');
});

test('requireAuth returns 401 when token is invalid', () => {
  const req = {
    headers: {
      authorization: 'Bearer invalid.token.here',
    },
  };
  const res = buildResponse();
  const next = mock.fn();

  requireAuth(req, res, next);

  assert.strictEqual(res.payload.statusCode, 401);
  assert.strictEqual(next.mock.callCount(), 0);
  assert.strictEqual(res.payload.body.error.code, 'unauthorized');
});

test('requireAuth calls next and assigns user when token is valid', () => {
  const token = jwt.sign({ sub: 'user-123' }, process.env.JWT_SECRET, { expiresIn: '1h' });
  const req = {
    headers: {
      authorization: `Bearer ${token}`,
    },
  };
  const res = buildResponse();
  const next = mock.fn();

  requireAuth(req, res, next);

  assert.strictEqual(next.mock.callCount(), 1);
  assert.deepStrictEqual(req.user, { id: 'user-123' });
  assert.strictEqual(res.payload.statusCode, null);
});
