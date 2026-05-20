BEGIN;

ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS customer_id text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS mobile_id bigint;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS order_source text NOT NULL DEFAULT 'WEB_APP';
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS total_cost numeric(12, 2);
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS tray_items jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS loyalty_points_restaurant_obtained integer NOT NULL DEFAULT 0;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS loyalty_reward_restaurant_obtained text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS delivery_address text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS delivery_lat double precision;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS delivery_lng double precision;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS delivery_notes text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS delivery_tracking_url text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS user_email text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_mode text NOT NULL DEFAULT 'GCASH ONLY';
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS delivery_time text DEFAULT 'NOW';
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_reference_initial text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_reference_balance text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_proof_initial text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_proof_balance text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_uploaded_initial boolean NOT NULL DEFAULT false;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_uploaded_balance boolean NOT NULL DEFAULT false;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_confirmed_initial boolean NOT NULL DEFAULT false;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_confirmed_balance boolean NOT NULL DEFAULT false;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS order_status text NOT NULL DEFAULT 'PENDING_CASHIER';
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS contact_number text NOT NULL DEFAULT '';
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS cashier_amount_received_initial numeric(12, 2);
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS cashier_amount_received_balance numeric(12, 2);
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS feedback_stars integer;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS feedback_remarks text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS amount_paid numeric(10, 2);
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS change_given numeric(10, 2);
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_method text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_proof text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS pos_customer_label text;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS balance_proof_pending_review boolean NOT NULL DEFAULT false;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS pos_claimed boolean NOT NULL DEFAULT false;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS pos_claimed_at timestamp with time zone;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS feedback_submitted_at timestamp with time zone;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS note text NOT NULL DEFAULT '';
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS payment_uploaded boolean NOT NULL DEFAULT false;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS submitted_order_dt_stamp timestamp with time zone;
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS last_updated_order_status_dt_stamp timestamp with time zone;

UPDATE public.restaurant_orders
SET
  tray_items = COALESCE(NULLIF(tray_items, '[]'::jsonb), items, '[]'::jsonb),
  total_cost = COALESCE(total_cost, total_amount, total),
  order_id = COALESCE(NULLIF(order_id, ''), order_no),
  contact_number = COALESCE(NULLIF(contact_number, ''), phone, delivery_contact, ''),
  user_email = COALESCE(user_email, guest_contact_email),
  loyalty_points_restaurant_obtained = COALESCE(loyalty_points_restaurant_obtained, points_earned, 0),
  cashier_amount_received_initial = COALESCE(cashier_amount_received_initial, cashier_amount_received),
  cashier_amount_received_balance = COALESCE(cashier_amount_received_balance, cashier_secondary_amount_received),
  payment_reference_initial = COALESCE(payment_reference_initial, payment_references_initial),
  payment_proof_balance = COALESCE(payment_proof_balance, supplemental_payment_proof),
  payment_confirmed_initial = COALESCE(payment_confirmed_initial, false) OR COALESCE(payment_status, '') = 'paid',
  payment_uploaded_initial = COALESCE(payment_uploaded_initial, false)
    OR payment_reference_initial IS NOT NULL
    OR payment_proof_initial IS NOT NULL,
  order_status = CASE
    WHEN upper(COALESCE(order_status, '')) IN ('PENDING', 'WAITING FOR ORDER CONFIRMATION') THEN 'PENDING_CASHIER'
    WHEN upper(COALESCE(order_status, '')) IN ('CONFIRMED', 'PREPARING') THEN 'IN_PREPARATION'
    WHEN upper(COALESCE(order_status, '')) IN ('PENDING_CASHIER', 'IN_PREPARATION', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED')
      THEN upper(order_status)
    ELSE 'PENDING_CASHIER'
  END,
  order_source = CASE
    WHEN upper(COALESCE(order_source, '')) IN ('POS', 'POS_WEB') THEN 'POS_WEB'
    WHEN upper(COALESCE(order_source, '')) = 'POS_MOBILE' THEN 'POS_MOBILE'
    WHEN upper(COALESCE(order_source, '')) IN ('MOBILE', 'MOBILE_APP') THEN 'MOBILE_APP'
    ELSE 'WEB_APP'
  END,
  updated_at = now();

DROP INDEX IF EXISTS public.restaurant_orders_order_no_uq;
DROP INDEX IF EXISTS public.restaurant_orders_order_id_uq;

ALTER TABLE public.restaurant_orders
  DROP COLUMN IF EXISTS items,
  DROP COLUMN IF EXISTS total_amount,
  DROP COLUMN IF EXISTS phone,
  DROP COLUMN IF EXISTS order_no,
  DROP COLUMN IF EXISTS points_earned,
  DROP COLUMN IF EXISTS guest_contact_email,
  DROP COLUMN IF EXISTS loyalty_points_catering_obtained,
  DROP COLUMN IF EXISTS cashier_secondary_amount_received,
  DROP COLUMN IF EXISTS payment_status,
  DROP COLUMN IF EXISTS fulfillment_stage,
  DROP COLUMN IF EXISTS supplemental_payment_proof,
  DROP COLUMN IF EXISTS delivery_name,
  DROP COLUMN IF EXISTS delivery_contact,
  DROP COLUMN IF EXISTS total,
  DROP COLUMN IF EXISTS cashier_change,
  DROP COLUMN IF EXISTS cashier_changer,
  DROP COLUMN IF EXISTS order_lines_snapshot,
  DROP COLUMN IF EXISTS payment_references_initial;

CREATE UNIQUE INDEX IF NOT EXISTS restaurant_orders_id_key
  ON public.restaurant_orders (id);
CREATE INDEX IF NOT EXISTS idx_restaurant_orders_created_at
  ON public.restaurant_orders (created_at DESC);

COMMIT;
