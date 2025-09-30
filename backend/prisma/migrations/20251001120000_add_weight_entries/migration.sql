-- Create enum type for weight entry source
DO $$
BEGIN
  CREATE TYPE "WeightEntrySource" AS ENUM ('MANUAL', 'AI', 'IMPORT');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Table to store weight measurements per user
CREATE TABLE IF NOT EXISTS "public"."WeightEntry" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "date" TIMESTAMP(3) NOT NULL,
  "weightKg" DECIMAL(5,2) NOT NULL,
  "note" TEXT,
  "source" "WeightEntrySource" NOT NULL DEFAULT 'MANUAL',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "WeightEntry_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "WeightEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "WeightEntry_weightKg_check" CHECK ("weightKg" >= 20 AND "weightKg" <= 400)
);

-- Index used for filtering by user and date ranges
DO $$
BEGIN
  CREATE INDEX "WeightEntry_userId_date_idx" ON "public"."WeightEntry" ("userId", "date");
EXCEPTION
  WHEN duplicate_table THEN NULL;
  WHEN duplicate_object THEN NULL;
END $$;

