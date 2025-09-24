-- Extend Recipe with richer fields and add ShoppingItem table

ALTER TABLE "public"."Recipe"
  ADD COLUMN IF NOT EXISTS "externalId" TEXT,
  ADD COLUMN IF NOT EXISTS "imageUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "readyInMin" INTEGER,
  ADD COLUMN IF NOT EXISTS "servings" INTEGER,
  ADD COLUMN IF NOT EXISTS "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS "ingredientsJson" JSONB,
  ADD COLUMN IF NOT EXISTS "nutrition" JSONB;

DO $$ BEGIN
  CREATE UNIQUE INDEX "Recipe_externalId_key" ON "public"."Recipe"("externalId");
EXCEPTION WHEN duplicate_table THEN NULL; WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS "public"."ShoppingItem" (
  "id" TEXT NOT NULL,
  "displayName" TEXT NOT NULL,
  "nameKey" TEXT NOT NULL,
  "qty" DOUBLE PRECISION,
  "unit" TEXT,
  "category" TEXT NOT NULL DEFAULT 'autres',
  "note" TEXT,
  "isChecked" BOOLEAN NOT NULL DEFAULT FALSE,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "listId" TEXT NOT NULL,
  CONSTRAINT "ShoppingItem_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ShoppingItem_listId_fkey" FOREIGN KEY ("listId") REFERENCES "public"."ShoppingList"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

DO $$ BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS "ShoppingItem_listId_nameKey_key" ON "public"."ShoppingItem"("listId", "nameKey");
EXCEPTION WHEN duplicate_table THEN NULL; WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE INDEX IF NOT EXISTS "ShoppingItem_listId_category_isChecked_idx" ON "public"."ShoppingItem"("listId", "category", "isChecked");
EXCEPTION WHEN duplicate_table THEN NULL; WHEN duplicate_object THEN NULL; END $$;

