-- ==============================================================================
-- FOODFLOW: REAL-TIME SHARED RESCUE & ATOMIC VOLUNTEER ASSIGNMENT SETUP
-- RUN THIS IN SUPABASE SQL EDITOR:
-- https://supabase.com/dashboard/project/rowjcupaeerzcqsmbvsj/sql
-- ==============================================================================

-- 1. ADD MISSING TELEMETRY, GPS, AND PRICING COLUMNS TO surplus_batches
ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS courier_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS courier_longitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS distance_remaining_km NUMERIC(5,2),
    ADD COLUMN IF NOT EXISTS assigning_started_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS receiver_dropoff_address TEXT,
    ADD COLUMN IF NOT EXISTS receiver_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS receiver_longitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS base_price NUMERIC(10,2) DEFAULT 50.0,
    ADD COLUMN IF NOT EXISTS floor_price NUMERIC(10,2) DEFAULT 10.0,
    ADD COLUMN IF NOT EXISTS locked_unit_price NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS locked_total_price NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS discount_at_purchase NUMERIC(5,1),
    ADD COLUMN IF NOT EXISTS time_remaining_hours_at_purchase NUMERIC(5,2);

-- 2. EXTEND STATUS CONSTRAINT TO COVER THE FULL 12-STAGE RESCUE LIFECYCLE
ALTER TABLE public.surplus_batches DROP CONSTRAINT IF EXISTS surplus_batches_status_check;
ALTER TABLE public.surplus_batches ADD CONSTRAINT surplus_batches_status_check CHECK (status IN (
    'available', 
    'claimed', 
    'volunteerAssigning', 
    'inTransitToPickup', 
    'arrivedAtPickup', 
    'pickedUp', 
    'inTransit', 
    'arrivedAtReceiver', 
    'delivered', 
    'expired', 
    'cancelled', 
    'reassigning'
));

-- 3. ATOMIC VOLUNTEER ASSIGNMENT RPC FUNCTION (PREVENTS RACE CONDITIONS)
-- Guarantees that if Volunteer A and Volunteer B tap 'Accept' simultaneously,
-- exactly ONE succeeds and returns true. The other receives false ('Task already assigned').
CREATE OR REPLACE FUNCTION public.claim_volunteer_task(
    p_batch_id TEXT,
    p_volunteer_id UUID,
    p_volunteer_name TEXT,
    p_volunteer_phone TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated INTEGER;
BEGIN
    UPDATE public.surplus_batches
    SET 
        status = 'volunteerAssigning',
        assigned_courier_id = p_volunteer_id,
        assigned_courier_name = p_volunteer_name,
        assigned_courier_phone = p_volunteer_phone,
        courier_eta_minutes = 12,
        assigning_started_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_batch_id
      AND (status = 'claimed' OR status = 'reassigning')
      AND (assigned_courier_id IS NULL OR assigned_courier_id = p_volunteer_id);

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;

-- 4. PERFORMANCE INDEXES FOR REALTIME QUERIES
CREATE INDEX IF NOT EXISTS idx_surplus_batches_status ON public.surplus_batches(status);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_provider_id ON public.surplus_batches(provider_id);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_claimed_ngo ON public.surplus_batches(claimed_by_ngo_id);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_assigned_courier ON public.surplus_batches(assigned_courier_id);

-- 5. REPLICA IDENTITY FULL (Broadcaster payload contains entire row for UPDATE & DELETE events)
ALTER TABLE public.surplus_batches REPLICA IDENTITY FULL;

-- 6. ENSURE surplus_batches IS REGISTERED IN SUPABASE REALTIME PUBLICATION
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

-- 7. ROW LEVEL SECURITY (RLS) POLICIES FOR REALTIME SYNC
ALTER TABLE public.surplus_batches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read of surplus_batches" ON public.surplus_batches;
CREATE POLICY "Allow public read of surplus_batches"
    ON public.surplus_batches FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Allow insert surplus_batches" ON public.surplus_batches;
CREATE POLICY "Allow insert surplus_batches"
    ON public.surplus_batches FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update surplus_batches" ON public.surplus_batches;
CREATE POLICY "Allow update surplus_batches"
    ON public.surplus_batches FOR UPDATE
    TO authenticated, anon
    USING (true)
    WITH CHECK (true);

-- Verification: Check active configuration
SELECT 
    schemaname, 
    tablename, 
    pubname 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' AND tablename = 'surplus_batches';
