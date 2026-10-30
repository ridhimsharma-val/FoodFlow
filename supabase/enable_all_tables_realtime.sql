-- ==============================================================================
-- FOODFLOW: ENABLE SUPABASE REALTIME ON ALL DATABASE TABLES
-- Copy and run this script in: Supabase Dashboard -> SQL Editor -> Run
-- ==============================================================================

-- 1. Enable REPLICA IDENTITY FULL
-- (Ensures INSERT, UPDATE, and DELETE broadcast payloads contain both old & new row data)
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.providers REPLICA IDENTITY FULL;
ALTER TABLE public.receivers REPLICA IDENTITY FULL;
ALTER TABLE public.surplus_batches REPLICA IDENTITY FULL;
ALTER TABLE public.volunteers REPLICA IDENTITY FULL;

-- 2. Add all 5 tables to the 'supabase_realtime' publication
DO $$
BEGIN
    -- profiles
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'profiles'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
    END IF;

    -- providers
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'providers'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.providers;
    END IF;

    -- receivers
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'receivers'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.receivers;
    END IF;

    -- surplus_batches
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'surplus_batches'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.surplus_batches;
    END IF;

    -- volunteers
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'volunteers'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.volunteers;
    END IF;
END $$;

-- 3. Verify Realtime status across all public tables
SELECT 
    schemaname, 
    tablename, 
    pubname 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' AND schemaname = 'public';
