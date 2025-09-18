const formatPayload = (payload) => {
  if (!payload) return '';
  if (payload instanceof Error) {
    return ` | error=${payload.message}`;
  }
  const serialized = JSON.stringify(payload);
  return serialized === '{}' ? '' : ` | meta=${serialized}`;
};

const log = (level, tag, message, payload) => {
  const time = new Date().toISOString();
  const base = `[${time}] [${level.toUpperCase()}] [${tag}] ${message}`;
  console[level === 'error' ? 'error' : 'log'](`${base}${formatPayload(payload)}`);
};

export const logInfo = (tag, message, meta) => {
  log('info', tag, message, meta);
};

export const logError = (tag, message, err) => {
  log('error', tag, message, err);
  if (err instanceof Error && err.stack) {
    console.error(err.stack);
  }
};
