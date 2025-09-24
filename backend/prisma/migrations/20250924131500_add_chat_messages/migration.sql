-- Create ChatMessage table for per-user chat history
CREATE TABLE IF NOT EXISTS "public"."ChatMessage" (
  "id" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "userId" TEXT NOT NULL,
  CONSTRAINT "ChatMessage_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ChatMessage_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

DO $$ BEGIN
  CREATE INDEX IF NOT EXISTS "ChatMessage_userId_createdAt_idx" ON "public"."ChatMessage"("userId", "createdAt");
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

