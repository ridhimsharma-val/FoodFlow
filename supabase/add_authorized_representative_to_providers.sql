-- ==============================================================================
-- FOODFLOW: SEPARATE AUTHORIZED REPRESENTATIVE & ORGANIZATION NAME IN SUPABASE
-- Run this in your Supabase Project -> SQL Editor
-- ==============================================================================

-- 1. Ensure public.providers has authorized_representative as a distinct column from organization_name
ALTER TABLE public.providers 
ADD COLUMN IF NOT EXISTS authorized_representative TEXT;

-- 2. Populate authorized_representative from contact_person for existing rows (if any)
UPDATE public.providers 
SET authorized_representative = contact_person 
WHERE authorized_representative IS NULL AND contact_person IS NOT NULL;

-- 3. Also ensure public.profiles has organization_name as a distinct column from full_name
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS organization_name TEXT;
