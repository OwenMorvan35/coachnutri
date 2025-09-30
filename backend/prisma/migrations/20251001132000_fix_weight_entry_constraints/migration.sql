-- Ensure weight entry schema matches current Prisma expectations
ALTER TABLE "public"."WeightEntry"
  ALTER COLUMN "weightKg" SET DATA TYPE DECIMAL(5,2),
  ALTER COLUMN "updatedAt" SET DEFAULT CURRENT_TIMESTAMP;

UPDATE "public"."WeightEntry"
SET "updatedAt" = CURRENT_TIMESTAMP
WHERE "updatedAt" IS NULL;

ALTER TABLE "public"."WeightEntry"
  DROP CONSTRAINT IF EXISTS "WeightEntry_userId_fkey";

ALTER TABLE "public"."WeightEntry"
  ADD CONSTRAINT "WeightEntry_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "public"."User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "public"."ChatMessage"
  DROP CONSTRAINT IF EXISTS "ChatMessage_userId_fkey";

ALTER TABLE "public"."ChatMessage"
  ADD CONSTRAINT "ChatMessage_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "public"."User"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "public"."ShoppingItem"
  DROP CONSTRAINT IF EXISTS "ShoppingItem_listId_fkey";

ALTER TABLE "public"."ShoppingItem"
  ADD CONSTRAINT "ShoppingItem_listId_fkey"
  FOREIGN KEY ("listId") REFERENCES "public"."ShoppingList"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
