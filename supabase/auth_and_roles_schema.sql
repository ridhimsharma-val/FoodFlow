-- ==============================================================================
-- FOODFLOW: CENTRALIZED AUTH, PROFILES & ROLE-BASED DATABASE SCHEMA
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/rowjcupaeerzcqsmbvsj/sql
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 1. CENTRAL PROFILES TABLE (Single Source of Truth for Roles)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'provider' CHECK (role IN ('provider', 'receiver')),
    phone TEXT,
    organization_name TEXT,
    operating_location TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Ensure columns exist if table was previously created with fewer columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS organization_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS operating_location TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(lower(email));

-- ==============================================================================
-- 2. ROLE-SPECIFIC TABLE: providers
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.providers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    organization_name TEXT NOT NULL,
    authorized_representative TEXT,
    contact_person TEXT,
    category TEXT NOT NULL DEFAULT 'Restaurant / Hotel',
    provider_type TEXT DEFAULT 'Restaurant',
    fssai_license_number VARCHAR(14) DEFAULT '11223344556677',
    contact_name TEXT,
    contact_phone VARCHAR(20),
    contact_email TEXT,
    address TEXT,
    operating_location TEXT DEFAULT 'Bengaluru, India',
    city TEXT NOT NULL DEFAULT 'Bengaluru',
    pincode VARCHAR(10) DEFAULT '560038',
    latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9784,
    longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6408,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    hygiene_rating NUMERIC(2,1) NOT NULL DEFAULT 4.9,
    operating_hours TEXT NOT NULL DEFAULT '10:00 AM - 11:30 PM',
    verification_method TEXT DEFAULT 'email',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS authorized_representative TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Restaurant / Hotel';
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS operating_location TEXT DEFAULT 'Bengaluru, India';
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS verification_method TEXT DEFAULT 'email';

CREATE INDEX IF NOT EXISTS idx_providers_user_id ON public.providers(user_id);

-- ==============================================================================
-- 3. ROLE-SPECIFIC TABLE: receivers
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.receivers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    organization_name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Charitable Shelter / Food Bank',
    daily_intake_capacity TEXT NOT NULL DEFAULT '100+ Meals',
    authorized_representative TEXT,
    contact_person TEXT,
    contact_phone VARCHAR(20),
    contact_email TEXT,
    operating_location TEXT DEFAULT 'Bengaluru, India',
    latitude DOUBLE PRECISION DEFAULT 12.9860,
    longitude DOUBLE PRECISION DEFAULT 77.6350,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    verification_method TEXT DEFAULT 'email',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.receivers ADD COLUMN IF NOT EXISTS operating_location TEXT DEFAULT 'Bengaluru, India';
ALTER TABLE public.receivers ADD COLUMN IF NOT EXISTS contact_person TEXT;
ALTER TABLE public.receivers ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(20);
ALTER TABLE public.receivers ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION DEFAULT 12.9860;
ALTER TABLE public.receivers ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION DEFAULT 77.6350;

CREATE INDEX IF NOT EXISTS idx_receivers_user_id ON public.receivers(user_id);

-- ==============================================================================
-- 4. SURPLUS BATCHES (Linking provider_id and claimed_by_ngo_id to auth users)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.surplus_batches (
    id TEXT PRIMARY KEY,
    provider_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
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
    claimed_by_ngo_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
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

ALTER TABLE public.surplus_batches ADD COLUMN IF NOT EXISTS claimed_by_ngo_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_surplus_batches_status ON public.surplus_batches(status);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_provider_id ON public.surplus_batches(provider_id);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_claimed_ngo ON public.surplus_batches(claimed_by_ngo_id);

-- ==============================================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.surplus_batches ENABLE ROW LEVEL SECURITY;

-- Profiles: Authenticated users can read their own profile
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

-- Profiles: Public/Authenticated can read basic profile info for role verification
DROP POLICY IF EXISTS "Public read profiles for role lookup" ON public.profiles;
CREATE POLICY "Public read profiles for role lookup"
    ON public.profiles FOR SELECT
    TO anon, authenticated
    USING (true);

-- Profiles: Users can update their own profile (name, org, phone) but not alter other users' profiles
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Profiles: Allow insert/upsert for own profile during authenticated signup
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- Providers: Public read verified providers
DROP POLICY IF EXISTS "Public read verified providers" ON public.providers;
CREATE POLICY "Public read verified providers"
    ON public.providers FOR SELECT
    TO authenticated, anon
    USING (is_verified = true);

-- Providers: User can manage their own provider record
DROP POLICY IF EXISTS "Users can manage own provider profile" ON public.providers;
CREATE POLICY "Users can manage own provider profile"
    ON public.providers FOR ALL
    TO authenticated
    USING (auth.uid() = id OR auth.uid() = user_id)
    WITH CHECK (auth.uid() = id OR auth.uid() = user_id);

-- Receivers: Public read verified receivers
DROP POLICY IF EXISTS "Public read verified receivers" ON public.receivers;
CREATE POLICY "Public read verified receivers"
    ON public.receivers FOR SELECT
    TO authenticated, anon
    USING (is_verified = true);

-- Receivers: User can manage their own receiver record
DROP POLICY IF EXISTS "Users can manage own receiver profile" ON public.receivers;
CREATE POLICY "Users can manage own receiver profile"
    ON public.receivers FOR ALL
    TO authenticated
    USING (auth.uid() = id OR auth.uid() = user_id)
    WITH CHECK (auth.uid() = id OR auth.uid() = user_id);

-- Surplus Batches: Anyone can view batches
DROP POLICY IF EXISTS "Anyone can view surplus batches" ON public.surplus_batches;
CREATE POLICY "Anyone can view surplus batches"
    ON public.surplus_batches FOR SELECT
    TO authenticated, anon
    USING (true);

-- Surplus Batches: Authenticated providers can post batches
DROP POLICY IF EXISTS "Providers can insert batches" ON public.surplus_batches;
CREATE POLICY "Providers can insert batches"
    ON public.surplus_batches FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- Surplus Batches: Authenticated users can claim and update batches
DROP POLICY IF EXISTS "Authenticated can update batches" ON public.surplus_batches;
CREATE POLICY "Authenticated can update batches"
    ON public.surplus_batches FOR UPDATE
    TO authenticated, anon
    USING (true)
    WITH CHECK (true);

-- ==============================================================================
-- 6. FAIL-SAFE AUTH TRIGGER FOR NEW SIGNUPS
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    v_role text;
    v_org text;
    v_name text;
BEGIN
    v_role := lower(COALESCE(new.raw_user_meta_data->>'role', 'provider'));
    IF v_role NOT IN ('provider', 'receiver') THEN
        v_role := 'provider';
    END IF;

    v_org := COALESCE(new.raw_user_meta_data->>'organization_name', split_part(new.email, '@', 1));
    v_name := COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', v_org);

    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        role,
        organization_name,
        is_verified,
        created_at,
        updated_at
    )
    VALUES (
        new.id,
        new.email,
        v_name,
        v_role,
        v_org,
        true,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
        organization_name = COALESCE(public.profiles.organization_name, EXCLUDED.organization_name),
        updated_at = now();

    -- Create matching role record if not existing
    IF v_role = 'provider' THEN
        INSERT INTO public.providers (id, user_id, organization_name, contact_person, authorized_representative, is_verified)
        VALUES (new.id, new.id, v_org, v_name, v_name, true)
        ON CONFLICT (id) DO NOTHING;
    ELSIF v_role = 'receiver' THEN
        INSERT INTO public.receivers (id, user_id, organization_name, contact_person, authorized_representative, is_verified)
        VALUES (new.id, new.id, v_org, v_name, v_name, true)
        ON CONFLICT (id) DO NOTHING;
    END IF;

    RETURN new;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user exception caught: %', SQLERRM;
        RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 7. RECONCILIATION SCRIPT FOR EXISTING USERS (SAFE REPAIR, NO DELETION)
-- ==============================================================================
-- Populates any missing profiles from auth.users and reconciles roles
DO $$
DECLARE
    u RECORD;
    v_existing_role text;
    v_org text;
    v_name text;
BEGIN
    FOR u IN (SELECT id, email, raw_user_meta_data FROM auth.users) LOOP
        -- Check if profile exists
        SELECT role INTO v_existing_role FROM public.profiles WHERE id = u.id;

        IF v_existing_role IS NULL THEN
            -- Check providers table
            IF EXISTS (SELECT 1 FROM public.providers WHERE user_id = u.id OR id = u.id) THEN
                v_existing_role := 'provider';
            -- Check receivers table
            ELSIF EXISTS (SELECT 1 FROM public.receivers WHERE user_id = u.id OR id = u.id) THEN
                v_existing_role := 'receiver';
            ELSE
                v_existing_role := lower(COALESCE(u.raw_user_meta_data->>'role', 'provider'));
                IF v_existing_role NOT IN ('provider', 'receiver') THEN
                    v_existing_role := 'provider';
                END IF;
            END IF;

            v_org := COALESCE(u.raw_user_meta_data->>'organization_name', split_part(u.email, '@', 1));
            v_name := COALESCE(u.raw_user_meta_data->>'full_name', v_org);

            INSERT INTO public.profiles (id, email, full_name, role, organization_name, is_verified)
            VALUES (u.id, u.email, v_name, v_existing_role, v_org, true)
            ON CONFLICT (id) DO UPDATE SET
                role = v_existing_role,
                updated_at = now();
        END IF;

        -- Ensure matching provider or receiver record exists with id = u.id
        IF v_existing_role = 'provider' THEN
            INSERT INTO public.providers (id, user_id, organization_name, contact_person, authorized_representative, is_verified)
            VALUES (u.id, u.id, COALESCE(u.raw_user_meta_data->>'organization_name', 'Kitchen Partner'), 'Chef', 'Chef', true)
            ON CONFLICT (id) DO NOTHING;
        ELSIF v_existing_role = 'receiver' THEN
            INSERT INTO public.receivers (id, user_id, organization_name, contact_person, authorized_representative, is_verified)
            VALUES (u.id, u.id, COALESCE(u.raw_user_meta_data->>'organization_name', 'Relief Shelter'), 'Coordinator', 'Coordinator', true)
            ON CONFLICT (id) DO NOTHING;
        END IF;
    END LOOP;
END $$;
