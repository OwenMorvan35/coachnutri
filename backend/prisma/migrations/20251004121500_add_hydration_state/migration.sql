CREATE TABLE IF NOT EXISTS "public"."HydrationState" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "consumedMl" INTEGER NOT NULL DEFAULT 0,
  "dailyGoalMl" INTEGER NOT NULL DEFAULT 2000,
  "lastResetAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastIntakeAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "HydrationState_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "HydrationState_userId_key" UNIQUE ("userId"),
  CONSTRAINT "HydrationState_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "public"."HydrationState" ("id", "userId")
SELECT gen_random_uuid(), u."id"
FROM "public"."User" u
WHERE NOT EXISTS (
  SELECT 1 FROM "public"."HydrationState" hs WHERE hs."userId" = u."id"
);
