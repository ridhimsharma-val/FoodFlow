-- ==============================================================================
-- FOODFLOW: SURPLUS BATCHES REALTIME DATABASE TABLE & POLICIES
-- Copy and run this script in your Supabase Project -> SQL Editor
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Drop existing table to ensure correct columns and types
DROP TABLE IF EXISTS public.surplus_batches CASCADE;

-- 2. Create table surplus_batches matching Flutter SurplusBatch model
CREATE TABLE public.surplus_batches (
    id TEXT PRIMARY KEY,
    provider_id UUID,
    provider_name TEXT NOT NULL DEFAULT 'Food Provider',
    provider_category TEXT NOT NULL DEFAULT 'Commercial Kitchen',
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Cooked Meals',
    quantity_portions INTEGER NOT NULL DEFAULT 1,
    dietary_type TEXT NOT NULL DEFAULT 'Pure Veg',
    cooked_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    safe_until TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now() + interval '4 hours'),
    temperature_celsius NUMERIC(4, 1) NOT NULL DEFAULT 65.0,
    packaging_type TEXT NOT NULL DEFAULT 'Insulated meal boxes',
    pickup_address TEXT NOT NULL DEFAULT '',
    pickup_latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9784,
    pickup_longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6408,
    pickup_otp VARCHAR(10) NOT NULL DEFAULT '1234',
    delivery_otp VARCHAR(10) NOT NULL DEFAULT '5678',
    status TEXT NOT NULL DEFAULT 'available',
    claimed_by_ngo_id UUID,
    claimed_by_ngo_name TEXT,
    assigned_courier_id UUID,
    assigned_courier_name TEXT,
    assigned_courier_phone TEXT,
    courier_eta_minutes INTEGER,
    claimed_at TIMESTAMPTZ,
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Performance indexes
CREATE INDEX IF NOT EXISTS idx_surplus_batches_status ON public.surplus_batches(status);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_provider ON public.surplus_batches(provider_id);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_safe_until ON public.surplus_batches(safe_until);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_created_at ON public.surplus_batches(created_at DESC);

-- 3. Automatic updated_at trigger
CREATE OR REPLACE FUNCTION public.handle_surplus_batches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_surplus_batches_updated_at ON public.surplus_batches;
CREATE TRIGGER trg_surplus_batches_updated_at
    BEFORE UPDATE ON public.surplus_batches
    FOR EACH ROW EXECUTE FUNCTION public.handle_surplus_batches_updated_at();

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.surplus_batches ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for real-time reads, inserts, updates, and deletes
DROP POLICY IF EXISTS "Public surplus batches read" ON public.surplus_batches;
CREATE POLICY "Public surplus batches read"
    ON public.surplus_batches FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Public surplus batches insert" ON public.surplus_batches;
CREATE POLICY "Public surplus batches insert"
    ON public.surplus_batches FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

DROP POLICY IF EXISTS "Public surplus batches update" ON public.surplus_batches;
CREATE POLICY "Public surplus batches update"
    ON public.surplus_batches FOR UPDATE
    TO authenticated, anon
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Public surplus batches delete" ON public.surplus_batches;
CREATE POLICY "Public surplus batches delete"
    ON public.surplus_batches FOR DELETE
    TO authenticated, anon
    USING (true);

-- 6. Enable Supabase Realtime Replication
-- Sets full replica identity so payload contains old & new row data
ALTER TABLE public.surplus_batches REPLICA IDENTITY FULL;

-- Add table to supabase_realtime publication (safe check)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'surplus_batches'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.surplus_batches;
    END IF;
END $$;
