import { nanoid } from 'nanoid';

export const requestId = (req, res, next) => {
  const id = nanoid();
  req.id = id;
  res.locals.requestId = id;
  next();
};
