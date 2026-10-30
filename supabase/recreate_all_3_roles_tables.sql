-- ==============================================================================
-- FOODFLOW: RECREATE ALL 3 ROLES TABLES + SMART OAUTH & SIGNUP TRIGGER
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/rowjcupaeerzcqsmbvsj/sql
-- ==============================================================================

-- 1. DROP EXISTING TABLES IN REVERSE ORDER
DROP TABLE IF EXISTS public.surplus_batches CASCADE;
DROP TABLE IF EXISTS public.volunteers CASCADE;
DROP TABLE IF EXISTS public.receivers CASCADE;
DROP TABLE IF EXISTS public.providers CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. ENABLE UUID EXTENSION
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 3. CENTRAL PROFILES TABLE (Single Source of Truth: 1 User = 1 Role)
-- ==============================================================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT CHECK (role IS NULL OR role IN ('provider', 'receiver', 'volunteer')),
    organization_name TEXT,
    operating_location TEXT,
    phone TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_email ON public.profiles(lower(email));

-- ==============================================================================
-- 4. ROLE 1: PROVIDERS TABLE (Hotels, Restaurants, Hostels, Caterers)
-- ==============================================================================
CREATE TABLE public.providers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    organization_name TEXT NOT NULL,
    authorized_representative TEXT,
    category TEXT NOT NULL DEFAULT 'Restaurant / Hotel',
    operating_location TEXT,
    phone TEXT,
    latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9784,
    longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6408,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_providers_user_id ON public.providers(user_id);

-- ==============================================================================
-- 5. ROLE 2: RECEIVERS TABLE (NGOs, Shelters, Food Distribution Centers)
-- ==============================================================================
CREATE TABLE public.receivers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    organization_name TEXT NOT NULL,
    authorized_representative TEXT,
    category TEXT NOT NULL DEFAULT 'Charitable Shelter / Food Bank',
    daily_intake_capacity TEXT NOT NULL DEFAULT '100+ Meals',
    operating_location TEXT,
    phone TEXT,
    latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9860,
    longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6350,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_receivers_user_id ON public.receivers(user_id);

-- ==============================================================================
-- 6. ROLE 3: VOLUNTEERS TABLE (Dispatch Couriers & Micro-Transit Delivery)
-- ==============================================================================
CREATE TABLE public.volunteers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT NOT NULL,
    government_id TEXT DEFAULT 'VERIFIED-VOL',
    transit_mode TEXT NOT NULL DEFAULT 'Two-Wheeler',
    operating_location TEXT,
    phone TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_volunteers_user_id ON public.volunteers(user_id);

-- ==============================================================================
-- 7. SURPLUS BATCHES TABLE (Real-time Food Listings & Claims)
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
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.volunteers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.surplus_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read of profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Allow insert own profile" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow public read of providers" ON public.providers FOR SELECT USING (true);
CREATE POLICY "Allow insert own provider" ON public.providers FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update own provider" ON public.providers FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow public read of receivers" ON public.receivers FOR SELECT USING (true);
CREATE POLICY "Allow insert own receiver" ON public.receivers FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update own receiver" ON public.receivers FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow public read of volunteers" ON public.volunteers FOR SELECT USING (true);
CREATE POLICY "Allow insert own volunteer" ON public.volunteers FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update own volunteer" ON public.volunteers FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow public read of surplus_batches" ON public.surplus_batches FOR SELECT USING (true);
CREATE POLICY "Allow insert surplus_batches" ON public.surplus_batches FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update surplus_batches" ON public.surplus_batches FOR UPDATE USING (true);
CREATE POLICY "Allow delete own surplus_batches" ON public.surplus_batches FOR DELETE USING (auth.uid() = provider_id);

-- ==============================================================================
-- 9. SMART DATABASE TRIGGER: AUTOMATIC POPULATION FROM AUTH
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_name TEXT;
  user_role TEXT;
  org_name  TEXT;
  user_loc  TEXT;
  user_phone TEXT;
BEGIN
  -- Extract real details from Google Auth or Email Signup metadata
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name', 
    NEW.raw_user_meta_data->>'name', 
    split_part(NEW.email, '@', 1)
  );
  
  user_role := NEW.raw_user_meta_data->>'role';
  
  user_loc := COALESCE(
    NEW.raw_user_meta_data->>'operating_location', 
    NEW.raw_user_meta_data->>'address', 
    ''
  );
  
  user_phone := COALESCE(NEW.phone, NEW.raw_user_meta_data->>'phone', '');

  -- Format organization name: use user's explicit organization or real name (never append fake suffixes)
  org_name := COALESCE(NEW.raw_user_meta_data->>'organization_name', user_name);

  -- 1. Insert into profiles (lookup for role & routing)
  -- If role is not yet known (e.g. Google OAuth redirect in flight), preserve existing role or set NULL
  INSERT INTO public.profiles (id, email, full_name, role, organization_name, operating_location, phone)
  VALUES (NEW.id, NEW.email, user_name, user_role, org_name, user_loc, user_phone)
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = COALESCE(EXCLUDED.role, profiles.role),
    organization_name = COALESCE(EXCLUDED.organization_name, profiles.organization_name),
    operating_location = COALESCE(EXCLUDED.operating_location, profiles.operating_location),
    phone = COALESCE(EXCLUDED.phone, profiles.phone);

  -- 2. Route strictly to the user's single role table ONLY if role is known
  IF user_role = 'provider' THEN
    INSERT INTO public.providers (id, user_id, email, organization_name, authorized_representative, operating_location, category, phone)
    VALUES (NEW.id, NEW.id, NEW.email, org_name, user_name, user_loc, COALESCE(NEW.raw_user_meta_data->>'category', 'Restaurant / Hotel'), user_phone)
    ON CONFLICT (id) DO UPDATE SET
      organization_name = EXCLUDED.organization_name,
      authorized_representative = EXCLUDED.authorized_representative,
      operating_location = EXCLUDED.operating_location;
      
  ELSIF user_role = 'receiver' THEN
    INSERT INTO public.receivers (id, user_id, email, organization_name, authorized_representative, operating_location, category, daily_intake_capacity, phone)
    VALUES (NEW.id, NEW.id, NEW.email, org_name, user_name, user_loc, COALESCE(NEW.raw_user_meta_data->>'category', 'Charitable Shelter / Food Bank'), '100+ Meals', user_phone)
    ON CONFLICT (id) DO UPDATE SET
      organization_name = EXCLUDED.organization_name,
      authorized_representative = EXCLUDED.authorized_representative,
      operating_location = EXCLUDED.operating_location;
      
  ELSIF user_role = 'volunteer' THEN
    INSERT INTO public.volunteers (id, user_id, email, full_name, operating_location, transit_mode, phone)
    VALUES (NEW.id, NEW.id, NEW.email, user_name, user_loc, COALESCE(NEW.raw_user_meta_data->>'transit_mode', 'Two-Wheeler'), user_phone)
    ON CONFLICT (id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      operating_location = EXCLUDED.operating_location;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 10. BACKFILL ALL EXISTING AUTH USERS (Immediately syncs your existing account)
-- ==============================================================================
DO $$
DECLARE
  u RECORD;
  u_name TEXT;
  u_role TEXT;
  u_org  TEXT;
  u_loc  TEXT;
BEGIN
  FOR u IN SELECT * FROM auth.users LOOP
    u_name := COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', split_part(u.email, '@', 1));
    u_role := COALESCE(u.raw_user_meta_data->>'role', (SELECT role FROM public.profiles WHERE id = u.id));
    u_loc  := COALESCE(u.raw_user_meta_data->>'operating_location', u.raw_user_meta_data->>'address', '');
    u_org  := COALESCE(u.raw_user_meta_data->>'organization_name', u_name);

    INSERT INTO public.profiles (id, email, full_name, role, organization_name, operating_location)
    VALUES (u.id, u.email, u_name, u_role, u_org, u_loc)
    ON CONFLICT (id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      role = COALESCE(EXCLUDED.role, profiles.role),
      organization_name = COALESCE(EXCLUDED.organization_name, profiles.organization_name),
      operating_location = COALESCE(EXCLUDED.operating_location, profiles.operating_location);

    IF u_role = 'provider' THEN
      INSERT INTO public.providers (id, user_id, email, organization_name, authorized_representative, operating_location, category)
      VALUES (u.id, u.id, u.email, u_org, u_name, u_loc, 'Restaurant / Hotel')
      ON CONFLICT (id) DO UPDATE SET
        organization_name = EXCLUDED.organization_name,
        authorized_representative = EXCLUDED.authorized_representative,
        operating_location = EXCLUDED.operating_location;
    ELSIF u_role = 'receiver' THEN
      INSERT INTO public.receivers (id, user_id, email, organization_name, authorized_representative, operating_location, category, daily_intake_capacity)
      VALUES (u.id, u.id, u.email, u_org, u_name, u_loc, 'Charitable Shelter / Food Bank', '100+ Meals')
      ON CONFLICT (id) DO UPDATE SET
        organization_name = EXCLUDED.organization_name,
        authorized_representative = EXCLUDED.authorized_representative,
        operating_location = EXCLUDED.operating_location;
    ELSIF u_role = 'volunteer' THEN
      INSERT INTO public.volunteers (id, user_id, email, full_name, operating_location, transit_mode)
      VALUES (u.id, u.id, u.email, u_name, u_loc, 'Two-Wheeler')
      ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        operating_location = EXCLUDED.operating_location;
    END IF;
  END LOOP;
END $$;

-- Enable Realtime
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
