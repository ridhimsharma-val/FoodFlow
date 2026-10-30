-- ==============================================================================
-- FOODFLOW: COMPLETE RESET & CLEAN RESTORATION SCRIPT
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/rowjcupaeerzcqsmbvsj/sql
-- ==============================================================================

-- 1. DROP OLD TABLES IN REVERSE DEPENDENCY ORDER
DROP TABLE IF EXISTS public.surplus_batches CASCADE;
DROP TABLE IF EXISTS public.receivers CASCADE;
DROP TABLE IF EXISTS public.providers CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. ENABLE UUID EXTENSION
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 3. PROFILES TABLE (Single Source of Truth for User Roles)
-- ==============================================================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'provider' CHECK (role IN ('provider', 'receiver')),
    phone TEXT,
    organization_name TEXT,
    operating_location TEXT DEFAULT 'Bengaluru, India',
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_email ON public.profiles(lower(email));

-- ==============================================================================
-- 4. PROVIDERS TABLE (Food Donors: Hotels, Restaurants, Caterers, Hostels)
-- ==============================================================================
CREATE TABLE public.providers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    organization_name TEXT NOT NULL,
    authorized_representative TEXT,
    category TEXT NOT NULL DEFAULT 'Restaurant / Hotel',
    operating_location TEXT DEFAULT 'Bengaluru, India',
    latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9784,
    longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6408,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_providers_user_id ON public.providers(user_id);

-- ==============================================================================
-- 5. RECEIVERS TABLE (Food Claimants: NGOs, Shelters, Relief Organizations)
-- ==============================================================================
CREATE TABLE public.receivers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    organization_name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Charitable Shelter / Food Bank',
    daily_intake_capacity TEXT NOT NULL DEFAULT '100+ Meals',
    authorized_representative TEXT,
    operating_location TEXT DEFAULT 'Bengaluru, India',
    latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9860,
    longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6350,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_receivers_user_id ON public.receivers(user_id);

-- ==============================================================================
-- 6. SURPLUS BATCHES TABLE (Real-time Food Listings & Claims)
-- ==============================================================================
CREATE TABLE public.surplus_batches (
    id TEXT PRIMARY KEY,
    provider_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    provider_name TEXT NOT NULL,
    provider_category TEXT NOT NULL DEFAULT 'Kitchen / Banquet',
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Cooked Meals',
    quantity_portions INTEGER NOT NULL CHECK (quantity_portions > 0),
    dietary_type TEXT NOT NULL DEFAULT 'Pure Veg',
    cooked_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    safe_until TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc'::text, now()) + interval '4 hours'),
    temperature_celsius NUMERIC(4, 1) NOT NULL DEFAULT 65.0,
    packaging_type TEXT NOT NULL DEFAULT 'Food-Grade Meal Boxes',
    pickup_address TEXT NOT NULL DEFAULT 'Bengaluru, India',
    pickup_latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9784,
    pickup_longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6408,
    pickup_otp VARCHAR(6) NOT NULL,
    delivery_otp VARCHAR(6) NOT NULL,
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN (
        'available', 'claimed', 'inTransitToPickup', 'pickedUp', 'delivered', 'expired'
    )),
    claimed_by_ngo_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    claimed_by_ngo_name TEXT,
    assigned_courier_name TEXT,
    assigned_courier_phone TEXT,
    courier_eta_minutes INTEGER,
    claimed_at TIMESTAMPTZ,
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_surplus_batches_status ON public.surplus_batches(status);
CREATE INDEX idx_surplus_batches_provider_id ON public.surplus_batches(provider_id);
CREATE INDEX idx_surplus_batches_claimed_ngo ON public.surplus_batches(claimed_by_ngo_id);

-- ==============================================================================
-- 7. SIMPLE ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.surplus_batches ENABLE ROW LEVEL SECURITY;

-- Profiles: Anyone authenticated can read; users can insert/update their own profile
CREATE POLICY "Allow public read of profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Allow insert own profile" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Providers: Anyone can read; users can insert/update their provider profile
CREATE POLICY "Allow public read of providers" ON public.providers FOR SELECT USING (true);
CREATE POLICY "Allow insert own provider" ON public.providers FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update own provider" ON public.providers FOR UPDATE USING (auth.uid() = id);

-- Receivers: Anyone can read; users can insert/update their receiver profile
CREATE POLICY "Allow public read of receivers" ON public.receivers FOR SELECT USING (true);
CREATE POLICY "Allow insert own receiver" ON public.receivers FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update own receiver" ON public.receivers FOR UPDATE USING (auth.uid() = id);

-- Surplus Batches: Everyone can view listings; authenticated users can insert and update
CREATE POLICY "Allow public read of surplus_batches" ON public.surplus_batches FOR SELECT USING (true);
CREATE POLICY "Allow insert surplus_batches" ON public.surplus_batches FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update surplus_batches" ON public.surplus_batches FOR UPDATE USING (true);
CREATE POLICY "Allow delete own surplus_batches" ON public.surplus_batches FOR DELETE USING (auth.uid() = provider_id);

-- ==============================================================================
-- 8. ENABLE REALTIME BROADCASTING ON SURPLUS BATCHES
-- ==============================================================================
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
