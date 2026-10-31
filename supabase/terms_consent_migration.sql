-- ==============================================================================
-- FOODFLOW: TERMS & CONDITIONS AND PRIVACY NOTICE USER CONSENT MIGRATION
-- ==============================================================================
-- Safe, idempotent migration to record user legal consent on public.profiles.
-- Run in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/rowjcupaeerzcqsmbvsj/sql
-- ==============================================================================

-- 1. Add terms consent tracking columns to public.profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS terms_accepted_version TEXT DEFAULT NULL;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS terms_consent_active BOOLEAN DEFAULT true;

-- 2. Index for quick policy version compliance audits
CREATE INDEX IF NOT EXISTS idx_profiles_terms_version 
ON public.profiles(terms_accepted_version);

-- 3. Comments describing the consent columns
COMMENT ON COLUMN public.profiles.terms_accepted_version IS 'Identifier of the Terms & Conditions / Privacy Notice policy version accepted by the user (e.g. foodflow_terms_v1)';
COMMENT ON COLUMN public.profiles.terms_accepted_at IS 'UTC Timestamp when the user explicitly accepted the terms';
COMMENT ON COLUMN public.profiles.terms_consent_active IS 'Active consent status: true if currently accepted, false if revoked';
