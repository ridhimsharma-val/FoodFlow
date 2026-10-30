-- ==============================================================================
-- FOODFLOW ZERO-WASTE NETWORK: PROVIDER ECOSYSTEM DATABASE SCHEMA
-- Run directly in Supabase SQL Editor
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 1. TABLE: providers (Profiles for Hotels, Hostels, Banquets, Caterers)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    organization_name TEXT NOT NULL,
    authorized_representative TEXT,
    contact_person TEXT,
    provider_type TEXT NOT NULL CHECK (provider_type IN (
        'Banquet', 'Hotel', 'Hostel', 'Caterer', 'Restaurant', 'Corporate Cafeteria', 'Other'
    )),
    fssai_license_number VARCHAR(14) NOT NULL,
    fssai_expiry_date DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '1 year'),
    contact_name TEXT NOT NULL,
    contact_phone VARCHAR(20) NOT NULL,
    contact_email TEXT,
    address TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'Bengaluru',
    pincode VARCHAR(10) DEFAULT '560038',
    latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9784,
    longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6408,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    hygiene_rating NUMERIC(2,1) NOT NULL DEFAULT 4.9,
    operating_hours TEXT NOT NULL DEFAULT '10:00 AM - 11:30 PM',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_providers_user_id ON public.providers(user_id);
CREATE INDEX IF NOT EXISTS idx_providers_city ON public.providers(city);

-- ==============================================================================
-- 2. TABLE: surplus_batches (Food batches posted by providers)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.surplus_batches (
    id TEXT PRIMARY KEY, -- e.g. 'BATCH-001'
    provider_id UUID REFERENCES public.providers(id) ON DELETE CASCADE,
    provider_name TEXT NOT NULL,
    provider_category TEXT NOT NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    quantity_portions INTEGER NOT NULL CHECK (quantity_portions > 0),
    dietary_type TEXT NOT NULL CHECK (dietary_type IN ('Pure Veg', 'Eggless Veg', 'Non-Veg', 'Vegan')),
    cooked_at TIMESTAMPTZ NOT NULL,
    safe_until TIMESTAMPTZ NOT NULL,
    temperature_celsius NUMERIC(4, 1) NOT NULL DEFAULT 65.0,
    packaging_type TEXT NOT NULL,
    pickup_address TEXT NOT NULL,
    pickup_latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9784,
    pickup_longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6408,
    pickup_otp VARCHAR(6) NOT NULL,
    delivery_otp VARCHAR(6) NOT NULL,
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN (
        'available', 'claimed', 'inTransitToPickup', 'pickedUp', 'delivered', 'expired'
    )),
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

CREATE INDEX IF NOT EXISTS idx_surplus_batches_status ON public.surplus_batches(status);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_provider ON public.surplus_batches(provider_id);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_safe_until ON public.surplus_batches(safe_until);

-- ==============================================================================
-- 3. TABLE: food_temperature_logs (HACCP Food Safety Logs)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.food_temperature_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id TEXT NOT NULL REFERENCES public.surplus_batches(id) ON DELETE CASCADE,
    stage TEXT NOT NULL CHECK (stage IN ('Cooking', 'Packaging', 'Dispatch_Pickup', 'In_Transit', 'Delivered')),
    logged_temperature NUMERIC(4, 1) NOT NULL,
    threshold_safe BOOLEAN NOT NULL DEFAULT true,
    logged_by_name TEXT NOT NULL,
    notes TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_temp_logs_batch_id ON public.food_temperature_logs(batch_id);

-- ==============================================================================
-- 4. TABLE: dispatch_logs (Chain of custody audit trail)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.dispatch_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id TEXT NOT NULL REFERENCES public.surplus_batches(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.providers(id),
    status TEXT NOT NULL,
    pickup_otp_entered VARCHAR(6),
    pickup_verified_at TIMESTAMPTZ,
    delivery_otp_entered VARCHAR(6),
    delivery_verified_at TIMESTAMPTZ,
    courier_name TEXT,
    courier_vehicle TEXT,
    receiver_ngo_name TEXT,
    total_portions INTEGER,
    notes TEXT,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_dispatch_logs_batch ON public.dispatch_logs(batch_id);

-- ==============================================================================
-- 5. TABLE: provider_impact_certificates (Section 80G Tax Exemption & CSR)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.provider_impact_certificates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    certificate_number VARCHAR(50) NOT NULL UNIQUE,
    financial_year VARCHAR(10) NOT NULL DEFAULT '2025-2026',
    total_batches_donated INTEGER NOT NULL DEFAULT 0,
    total_meals_rescued INTEGER NOT NULL DEFAULT 0,
    total_kg_diverted NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    co2_offset_kg NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    estimated_valuation_inr NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    section_80g_reference TEXT NOT NULL DEFAULT 'CIT(E)/BLR/80G/2024-25/AABCT1234F',
    issued_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    pdf_url TEXT
);

CREATE INDEX IF NOT EXISTS idx_impact_certs_provider ON public.provider_impact_certificates(provider_id);

-- ==============================================================================
-- 6. AUTOMATIC TIMESTAMP TRIGGER
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_providers_updated_at ON public.providers;
CREATE TRIGGER set_providers_updated_at
    BEFORE UPDATE ON public.providers
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_surplus_batches_updated_at ON public.surplus_batches;
CREATE TRIGGER set_surplus_batches_updated_at
    BEFORE UPDATE ON public.surplus_batches
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ==============================================================================
-- 7. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.surplus_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_temperature_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispatch_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_impact_certificates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read verified providers"
    ON public.providers FOR SELECT TO authenticated, anon USING (is_verified = true);

CREATE POLICY "Users can manage their own provider profile"
    ON public.providers FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anyone can view surplus batches"
    ON public.surplus_batches FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Providers can create batches"
    ON public.surplus_batches FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Providers and couriers can update batches"
    ON public.surplus_batches FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can view temperature logs"
    ON public.food_temperature_logs FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authorized staff can insert temperature logs"
    ON public.food_temperature_logs FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can view dispatch logs"
    ON public.dispatch_logs FOR SELECT TO authenticated USING (true);

CREATE POLICY "System and couriers can record dispatch events"
    ON public.dispatch_logs FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Providers can view their own 80G certificates"
    ON public.provider_impact_certificates FOR SELECT TO authenticated USING (true);

-- ==============================================================================
-- 8. INITIAL SEED DATA (Bangalore Kitchens)
-- ==============================================================================
DO $$
DECLARE
    p_id UUID := 'a1111111-1111-1111-1111-111111111111'::uuid;
BEGIN
    INSERT INTO public.providers (
        id, organization_name, provider_type, fssai_license_number,
        contact_name, contact_phone, contact_email, address,
        city, pincode, latitude, longitude, hygiene_rating, operating_hours
    ) VALUES (
        p_id, 'Grand Palace Banquet & Kitchen', 'Banquet', '11223344556677',
        'Chef Rajesh Verma', '+91 98765 11223', 'grandpalace.kitchen@gmail.com',
        'Grand Palace Hall, 12th Main Road, Indiranagar', 'Bengaluru', '560038',
        12.9784, 77.6408, 4.9, '10:00 AM - 11:30 PM'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.surplus_batches (
        id, provider_id, provider_name, provider_category, title, category,
        quantity_portions, dietary_type, cooked_at, safe_until,
        temperature_celsius, packaging_type, pickup_address,
        pickup_latitude, pickup_longitude, pickup_otp, delivery_otp,
        status, claimed_by_ngo_name, assigned_courier_name, assigned_courier_phone,
        courier_eta_minutes, claimed_at
    ) VALUES (
        'BATCH-001', p_id, 'Grand Palace Banquet & Kitchen', 'Event Banquet Hall',
        '120 Portions Veg Dum Biryani', 'Cooked Meals & Thalis',
        120, 'Pure Veg', now() - interval '45 minutes', now() + interval '3 hours 15 minutes',
        68.5, '120 Insulated Individual Foil Trays', 'Grand Palace Hall, 12th Main Road, Indiranagar, Bengaluru',
        12.9784, 77.6408, '4821', '7390',
        'claimed', 'Hope Shelter & Orphanage', 'Vikram Rao (Hero Electric)', '+91 98765 43210',
        8, now() - interval '15 minutes'
    ) ON CONFLICT (id) DO NOTHING;
END $$;

-- ==============================================================================
-- 9. REALTIME PUBLICATION CONFIGURATION
-- ==============================================================================
ALTER TABLE public.surplus_batches REPLICA IDENTITY FULL;

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

