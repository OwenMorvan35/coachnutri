DO $$
BEGIN
  CREATE TYPE "Gender" AS ENUM ('FEMALE', 'MALE', 'OTHER', 'UNSPECIFIED');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "GoalType" AS ENUM ('LOSE', 'MAINTAIN', 'GAIN', 'UNSPECIFIED');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "ActivityLevel" AS ENUM ('SEDENTARY', 'LIGHT', 'MODERATE', 'ACTIVE', 'VERY_ACTIVE', 'UNSPECIFIED');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "public"."HealthProfile" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "gender" "Gender" NOT NULL DEFAULT 'UNSPECIFIED',
  "birthDate" TIMESTAMP(3),
  "heightCm" DOUBLE PRECISION,
  "startingWeightKg" DOUBLE PRECISION,
  "goal" "GoalType" NOT NULL DEFAULT 'UNSPECIFIED',
  "activityLevel" "ActivityLevel" NOT NULL DEFAULT 'UNSPECIFIED',
  "allergies" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "dietaryPreferences" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "constraints" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "budgetConstraint" TEXT,
  "timeConstraint" TEXT,
  "medicalConditions" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "HealthProfile_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "HealthProfile_userId_key" UNIQUE ("userId"),
  CONSTRAINT "HealthProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "public"."HealthProfile" ("id", "userId")
SELECT gen_random_uuid(), u."id"
FROM "public"."User" u
WHERE NOT EXISTS (
  SELECT 1 FROM "public"."HealthProfile" hp WHERE hp."userId" = u."id"
);
