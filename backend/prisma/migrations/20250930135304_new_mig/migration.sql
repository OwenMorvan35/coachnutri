-- DropForeignKey
ALTER TABLE "public"."WeightEntry" DROP CONSTRAINT "WeightEntry_userId_fkey";

-- AlterTable
ALTER TABLE "public"."WeightEntry" ALTER COLUMN "weightKg" SET DATA TYPE DECIMAL(65,30),
ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AddForeignKey
ALTER TABLE "public"."WeightEntry" ADD CONSTRAINT "WeightEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
