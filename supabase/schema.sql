-- ====================================================================
-- AQUASHARE — SUPABASE DATABASE SCHEMA & REALTIME SETUP
-- ====================================================================
-- Tables:
-- 1. bookings   (id, farmer_name, pump_id, date, slot_start, slot_end, status, meter_start, meter_end, water_drawn, created_at)
-- 2. reports    (id, pump_id, reporter_name, report_type, details, resolved, created_at)
-- 3. water_log  (id, booking_id, farmer_name, pump_id, date, water_drawn, flagged, created_at)
-- ====================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------------------
-- TABLE 1: BOOKINGS
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farmer_name TEXT NOT NULL,
    pump_id INTEGER NOT NULL CHECK (pump_id BETWEEN 1 AND 5),
    date DATE NOT NULL,
    slot_start TIME NOT NULL,
    slot_end TIME NOT NULL,
    status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'completed', 'missed', 'interrupted', 'cancelled')),
    meter_start NUMERIC(10,2) NULL,
    meter_end NUMERIC(10,2) NULL,
    water_drawn NUMERIC(10,2) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast slot conflict lookups
CREATE INDEX IF NOT EXISTS idx_bookings_lookup ON public.bookings (pump_id, date, slot_start, slot_end);

-- --------------------------------------------------------------------
-- TABLE 2: REPORTS
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pump_id INTEGER NOT NULL CHECK (pump_id BETWEEN 1 AND 5),
    reporter_name TEXT NOT NULL,
    report_type TEXT NOT NULL CHECK (report_type IN ('broken', 'overrun')),
    details TEXT NULL,
    resolved BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for active reports by pump
CREATE INDEX IF NOT EXISTS idx_reports_pump_resolved ON public.reports (pump_id, resolved, report_type);

-- --------------------------------------------------------------------
-- TABLE 3: WATER_LOG
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.water_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE,
    farmer_name TEXT NOT NULL,
    pump_id INTEGER NOT NULL CHECK (pump_id BETWEEN 1 AND 5),
    date DATE NOT NULL,
    water_drawn NUMERIC(10,2) NOT NULL,
    flagged BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for daily water sum calculation
CREATE INDEX IF NOT EXISTS idx_water_log_date ON public.water_log (date);

-- --------------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Free community app: Allow public anonymous read/insert/update
-- --------------------------------------------------------------------
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_log ENABLE ROW LEVEL SECURITY;

-- Bookings policies
DROP POLICY IF EXISTS "Public read bookings" ON public.bookings;
CREATE POLICY "Public read bookings" ON public.bookings FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public insert bookings" ON public.bookings;
CREATE POLICY "Public insert bookings" ON public.bookings FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Public update bookings" ON public.bookings;
CREATE POLICY "Public update bookings" ON public.bookings FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- Reports policies
DROP POLICY IF EXISTS "Public read reports" ON public.reports;
CREATE POLICY "Public read reports" ON public.reports FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public insert reports" ON public.reports;
CREATE POLICY "Public insert reports" ON public.reports FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Public update reports" ON public.reports;
CREATE POLICY "Public update reports" ON public.reports FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- Water log policies
DROP POLICY IF EXISTS "Public read water_log" ON public.water_log;
CREATE POLICY "Public read water_log" ON public.water_log FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public insert water_log" ON public.water_log;
CREATE POLICY "Public insert water_log" ON public.water_log FOR INSERT TO anon, authenticated WITH CHECK (true);

-- --------------------------------------------------------------------
-- SUPABASE REALTIME PUBLICATION
-- Enables instant subscriptions across all open devices
-- --------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'bookings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'reports'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.reports;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'water_log'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.water_log;
    END IF;
END $$;
