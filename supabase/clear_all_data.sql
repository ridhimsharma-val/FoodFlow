-- ==============================================================================
-- FOODFLOW: CLEAN ALL USERS & DATA (PRESERVES TABLES, SCHEMAS & POLICIES)
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/rowjcupaeerzcqsmbvsj/sql
-- ==============================================================================

-- 1. TRUNCATE ALL PUBLIC TABLES (FOOD DONATIONS, PROFILES, ROLES, VOLUNTEERS)
-- Loops through every table in the 'public' schema and truncates data with CASCADE.
-- Preserves table definitions, columns, indexes, RLS policies, and triggers.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    ) LOOP
        EXECUTE 'TRUNCATE TABLE public.' || quote_ident(r.tablename) || ' RESTART IDENTITY CASCADE;';
    END LOOP;
END $$;

-- 2. DELETE ALL USERS FROM SUPABASE AUTH
-- Deleting from auth.users cascades to auth.identities, auth.sessions,
-- auth.refresh_tokens, auth.mfa_factors, and auth.audit_log_entries.
DELETE FROM auth.users;

-- 3. (OPTIONAL) VERIFY THAT ALL TABLES ARE NOW EMPTY (COUNT = 0)
SELECT 'public.' || tablename AS table_name, 
       (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', tablename), false, true, '')))[1]::text::int AS row_count
FROM pg_tables
WHERE schemaname = 'public'
UNION ALL
SELECT 'auth.users' AS table_name, count(*) FROM auth.users;
