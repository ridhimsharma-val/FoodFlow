-- ==============================================================================
-- CHECK EMAIL REGISTERED FUNCTION (RPC)
-- Allows anonymous or authenticated clients to check if an email is registered
-- without exposing full user records.
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/rowjcupaeerzcqsmbvsj/sql
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.check_email_registered(check_email text)
RETURNS jsonb AS $$
DECLARE
  v_role text := NULL;
  v_found boolean := false;
BEGIN
  -- 1. Check in public.profiles for an active role
  SELECT role INTO v_role FROM public.profiles 
  WHERE lower(email) = lower(trim(check_email)) AND role IS NOT NULL 
  LIMIT 1;
  IF FOUND AND v_role IS NOT NULL THEN
    v_found := true;
  END IF;

  -- 2. Check in public.providers
  IF NOT v_found AND EXISTS (SELECT 1 FROM public.providers WHERE lower(email) = lower(trim(check_email))) THEN
    v_found := true;
    v_role := 'provider';
  END IF;

  -- 3. Check in public.receivers
  IF NOT v_found AND EXISTS (SELECT 1 FROM public.receivers WHERE lower(email) = lower(trim(check_email))) THEN
    v_found := true;
    v_role := 'receiver';
  END IF;

  -- 4. Check in public.volunteers
  IF NOT v_found AND EXISTS (SELECT 1 FROM public.volunteers WHERE lower(email) = lower(trim(check_email))) THEN
    v_found := true;
    v_role := 'volunteer';
  END IF;

  IF v_found THEN
    RETURN jsonb_build_object('exists', true, 'role', v_role);
  ELSE
    RETURN jsonb_build_object('exists', false);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_email_registered(text) TO anon, authenticated, service_role;
