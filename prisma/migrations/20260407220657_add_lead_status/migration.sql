-- CreateEnum
CREATE TYPE "LeadStatus" AS ENUM ('new', 'contacted', 'rejected');

-- AlterTable
ALTER TABLE "leads" ADD COLUMN     "status" "LeadStatus" NOT NULL DEFAULT 'new';
