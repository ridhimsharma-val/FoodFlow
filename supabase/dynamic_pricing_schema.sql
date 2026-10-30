-- ==============================================================================
-- FOODFLOW: DYNAMIC PRICING / SMART MARKDOWN PRICING SYSTEM SCHEMA MIGRATION
-- Adds static pricing inputs and locked transaction fields to surplus_batches
-- ==============================================================================

-- 1. Static pricing inputs (compute-on-read model)
ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS base_price NUMERIC(10, 2) NOT NULL DEFAULT 50.0;

ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS floor_price NUMERIC(10, 2) NOT NULL DEFAULT 10.0;

ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS food_type TEXT NOT NULL DEFAULT 'normal';

ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS quality_tier TEXT NOT NULL DEFAULT 'tier1';

ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS clear_kitchen BOOLEAN NOT NULL DEFAULT false;

-- 2. Locked transaction pricing inputs (locked at moment of purchase/claim)
ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS locked_unit_price NUMERIC(10, 2);

ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS locked_total_price NUMERIC(10, 2);

ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS discount_at_purchase NUMERIC(5, 2);

ALTER TABLE public.surplus_batches 
    ADD COLUMN IF NOT EXISTS time_remaining_hours_at_purchase NUMERIC(5, 2);

-- 3. Performance indexes for pricing queries
CREATE INDEX IF NOT EXISTS idx_surplus_batches_pricing ON public.surplus_batches(base_price, floor_price);
CREATE INDEX IF NOT EXISTS idx_surplus_batches_food_type ON public.surplus_batches(food_type);
