-- LIVE SUPABASE SCHEMA — VIEWS\n\ncreate or replace view public.accounting_monthly_summary as  WITH sales AS (
         SELECT date_trunc('month'::text, (orders.created_at AT TIME ZONE 'America/Puerto_Rico'::text))::date AS month,
            COALESCE(sum(orders.total) FILTER (WHERE COALESCE(orders.sales_channel, 'store'::text) <> 'doordash'::text AND orders.payment_method = 'cash'::text), 0::numeric) AS sales_cash,
            COALESCE(sum(orders.total) FILTER (WHERE COALESCE(orders.sales_channel, 'store'::text) <> 'doordash'::text AND orders.payment_method = 'card'::text), 0::numeric) AS sales_card,
            COALESCE(sum(orders.total) FILTER (WHERE COALESCE(orders.sales_channel, 'store'::text) <> 'doordash'::text AND orders.payment_method = 'ath_movil'::text), 0::numeric) AS sales_ath_movil,
            COALESCE(sum(orders.total) FILTER (WHERE COALESCE(orders.sales_channel, 'store'::text) <> 'doordash'::text AND (orders.payment_method = 'other'::text OR orders.payment_method IS NULL)), 0::numeric) AS sales_other,
            COALESCE(sum(orders.total) FILTER (WHERE orders.sales_channel = 'doordash'::text), 0::numeric) AS sales_doordash,
            COALESCE(sum(orders.total), 0::numeric) AS sales_total
           FROM orders
          WHERE orders.status = 'completed'::text
          GROUP BY (date_trunc('month'::text, (orders.created_at AT TIME ZONE 'America/Puerto_Rico'::text))::date)
        ), exp AS (
         SELECT date_trunc('month'::text, receipts.receipt_date::timestamp with time zone)::date AS month,
            COALESCE(sum(receipts.amount) FILTER (WHERE receipts.payment_method = 'cash'::text), 0::numeric) AS expenses_cash,
            COALESCE(sum(receipts.amount) FILTER (WHERE receipts.payment_method = 'card'::text), 0::numeric) AS expenses_card,
            COALESCE(sum(receipts.amount) FILTER (WHERE receipts.payment_method = 'ath_movil'::text), 0::numeric) AS expenses_ath_movil,
            COALESCE(sum(receipts.amount) FILTER (WHERE receipts.payment_method = 'other'::text OR receipts.payment_method IS NULL), 0::numeric) AS expenses_other,
            COALESCE(sum(receipts.amount), 0::numeric) AS expenses_total
           FROM receipts
          WHERE receipts.receipt_type = 'expense'::text
          GROUP BY (date_trunc('month'::text, receipts.receipt_date::timestamp with time zone)::date)
        )
 SELECT COALESCE(s.month, e.month) AS month,
    COALESCE(s.sales_cash, 0::numeric) AS sales_cash,
    COALESCE(s.sales_card, 0::numeric) AS sales_card,
    COALESCE(s.sales_ath_movil, 0::numeric) AS sales_ath_movil,
    COALESCE(s.sales_other, 0::numeric) AS sales_other,
    COALESCE(s.sales_doordash, 0::numeric) AS sales_doordash,
    COALESCE(s.sales_total, 0::numeric) AS sales_total,
    COALESCE(e.expenses_cash, 0::numeric) AS expenses_cash,
    COALESCE(e.expenses_card, 0::numeric) AS expenses_card,
    COALESCE(e.expenses_ath_movil, 0::numeric) AS expenses_ath_movil,
    COALESCE(e.expenses_other, 0::numeric) AS expenses_other,
    COALESCE(e.expenses_total, 0::numeric) AS expenses_total,
    COALESCE(s.sales_total, 0::numeric) - COALESCE(e.expenses_total, 0::numeric) AS net
   FROM sales s
     FULL JOIN exp e ON s.month = e.month;;\n\ncreate or replace view public.current_sales_dashboard as  SELECT month,
    orders_count,
    gross_sales,
    discounts,
    net_sales,
    tax_collected,
    billed_total,
    estimated_product_cost,
    estimated_gross_profit,
    estimated_margin_percent,
    monthly_goal,
    goal_progress_percent
   FROM monthly_sales_dashboard
  WHERE month = date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date;;\n\ncreate or replace view public.dashboard_channel_prices as  SELECT mcp.id,
    mcp.item_id,
    mi.name AS product_name,
    mcp.size_id,
    mis.size_oz,
    mis.size_name,
    mcp.channel,
    mcp.price,
    mcp.active,
    mcp.updated_at
   FROM menu_channel_prices mcp
     JOIN menu_items mi ON mi.id = mcp.item_id
     LEFT JOIN menu_item_sizes mis ON mis.id = mcp.size_id
  WHERE mcp.active = true;;\n\ncreate or replace view public.dashboard_current_goal as  WITH goal AS (
         SELECT COALESCE(( SELECT sg.sales_goal
                   FROM sales_goals sg
                  WHERE sg.goal_month = date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date AND sg.active = true
                  ORDER BY sg.id DESC
                 LIMIT 1), 0::numeric) AS sales_goal
        ), sales AS (
         SELECT COALESCE(sum(o.total) FILTER (WHERE o.status = 'completed'::text), 0::numeric) AS current_sales,
            count(*) FILTER (WHERE o.status = 'completed'::text) AS total_orders
           FROM orders o
          WHERE o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) AND o.created_at < (date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) + '1 mon'::interval)
        )
 SELECT date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date AS goal_month,
    g.sales_goal,
    s.current_sales,
    s.total_orders,
        CASE
            WHEN g.sales_goal > 0::numeric THEN round(s.current_sales / g.sales_goal * 100::numeric, 2)
            ELSE 0::numeric
        END AS progress_percent,
    GREATEST(g.sales_goal - s.current_sales, 0::numeric) AS remaining_to_goal,
        CASE
            WHEN g.sales_goal > 0::numeric THEN GREATEST(g.sales_goal - s.current_sales, 0::numeric)
            ELSE 0::numeric
        END AS amount_needed
   FROM goal g
     CROSS JOIN sales s;;\n\ncreate or replace view public.dashboard_daily_sales as  SELECT d.d::date AS sale_date,
    COALESCE(count(o.id), 0::bigint) AS orders_count,
    COALESCE(sum(o.subtotal - o.discount), 0::numeric)::numeric(12,2) AS net_sales,
    COALESCE(sum(o.tax), 0::numeric)::numeric(12,2) AS tax_collected,
    COALESCE(sum(o.total), 0::numeric)::numeric(12,2) AS billed_total
   FROM generate_series(date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date::timestamp with time zone, CURRENT_DATE::timestamp with time zone, '1 day'::interval) d(d)
     LEFT JOIN orders o ON o.created_at::date = d.d::date AND o.status = 'completed'::text
  GROUP BY d.d
  ORDER BY d.d;;\n\ncreate or replace view public.dashboard_finance_branch as  SELECT date_trunc('month'::text, day::timestamp with time zone)::date AS month,
    sum(sales_total) AS sales_total,
    sum(discounts) AS discounts,
    sum(product_cost_total) AS product_cost_total,
    sum(payroll_total) AS payroll_total,
    sum(expenses_total) AS expenses_total,
    sum(estimated_net) AS estimated_net
   FROM financial_daily_summary d
  GROUP BY (date_trunc('month'::text, day::timestamp with time zone)::date);;\n\ncreate or replace view public.dashboard_goals_branch as  SELECT sg.goal_month,
    sg.sales_goal,
    COALESCE(sum(o.total) FILTER (WHERE o.status = 'completed'::text), 0::numeric) AS current_sales,
    count(o.id) FILTER (WHERE o.status = 'completed'::text) AS total_orders,
        CASE
            WHEN sg.sales_goal > 0::numeric THEN round(COALESCE(sum(o.total) FILTER (WHERE o.status = 'completed'::text), 0::numeric) / sg.sales_goal * 100::numeric, 2)
            ELSE 0::numeric
        END AS progress_percent,
    GREATEST(sg.sales_goal - COALESCE(sum(o.total) FILTER (WHERE o.status = 'completed'::text), 0::numeric), 0::numeric) AS remaining_to_goal
   FROM sales_goals sg
     LEFT JOIN orders o ON date_trunc('month'::text, o.created_at)::date = sg.goal_month
  GROUP BY sg.goal_month, sg.sales_goal;;\n\ncreate or replace view public.dashboard_inventory_branch as  SELECT i.id AS ingredient_id,
    i.name,
    i.unit,
    i.current_quantity,
    i.minimum_quantity,
    i.cost_per_unit,
    i.active,
    i.current_quantity <= i.minimum_quantity AS low_stock,
    COALESCE(sum(im.quantity) FILTER (WHERE im.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)), 0::numeric) AS month_movement
   FROM ingredients i
     LEFT JOIN inventory_movements im ON im.ingredient_id = i.id
  GROUP BY i.id, i.name, i.unit, i.current_quantity, i.minimum_quantity, i.cost_per_unit, i.active;;\n\ncreate or replace view public.dashboard_low_inventory as  SELECT ingredient_id,
    name,
    unit,
    current_quantity,
    minimum_quantity,
    cost_per_unit,
    low_stock,
    active
   FROM inventory_status
  WHERE active = true AND low_stock = true
  ORDER BY current_quantity, name;;\n\ncreate or replace view public.dashboard_low_selling_products as  SELECT mi.id AS item_id,
    mi.name AS product_name,
    COALESCE(sum(
        CASE
            WHEN o.status = 'completed'::text AND o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) THEN oi.quantity
            ELSE 0
        END), 0::bigint) AS units_sold,
    COALESCE(sum(
        CASE
            WHEN o.status = 'completed'::text AND o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) THEN oi.line_total
            ELSE 0::numeric
        END), 0::numeric)::numeric(12,2) AS sales
   FROM menu_items mi
     LEFT JOIN order_items oi ON oi.item_id = mi.id
     LEFT JOIN orders o ON o.id = oi.order_id
  WHERE mi.active = true
  GROUP BY mi.id, mi.name
  ORDER BY (COALESCE(sum(
        CASE
            WHEN o.status = 'completed'::text AND o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) THEN oi.quantity
            ELSE 0
        END), 0::bigint)), (COALESCE(sum(
        CASE
            WHEN o.status = 'completed'::text AND o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) THEN oi.line_total
            ELSE 0::numeric
        END), 0::numeric)::numeric(12,2));;\n\ncreate or replace view public.dashboard_main as  SELECT COALESCE(sum(total) FILTER (WHERE status = 'completed'::text AND created_at::date = CURRENT_DATE), 0::numeric) AS today_sales,
    count(id) FILTER (WHERE status = 'completed'::text AND created_at::date = CURRENT_DATE) AS today_orders,
    COALESCE(sum(total) FILTER (WHERE status = 'completed'::text AND created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)), 0::numeric) AS month_sales,
    count(id) FILTER (WHERE status = 'completed'::text AND created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)) AS month_orders,
        CASE
            WHEN count(id) FILTER (WHERE status = 'completed'::text AND created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)) > 0 THEN round(COALESCE(sum(total) FILTER (WHERE status = 'completed'::text AND created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)), 0::numeric) / count(id) FILTER (WHERE status = 'completed'::text AND created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone))::numeric, 2)
            ELSE 0::numeric
        END AS average_order
   FROM orders o;;\n\ncreate or replace view public.dashboard_menu_branch as  SELECT mi.id AS item_id,
    mi.name AS product_name,
    mi.category_id,
    mc.name AS category_name,
    mi.active,
    mi.featured,
    mi.seasonal,
    mi.base_price,
    mis.id AS size_id,
    mis.size_oz,
    mis.size_name,
    mis.price AS size_price,
    mcp.channel,
    mcp.price AS channel_price,
    me.id AS extra_id,
    me.name AS extra_name,
    me.price AS extra_price,
    pe.selection_group
   FROM menu_items mi
     LEFT JOIN menu_categories mc ON mc.id = mi.category_id
     LEFT JOIN menu_item_sizes mis ON mis.item_id = mi.id AND mis.active = true
     LEFT JOIN menu_channel_prices mcp ON mcp.item_id = mi.id AND NOT mcp.size_id IS DISTINCT FROM mis.id AND mcp.active = true
     LEFT JOIN product_extras pe ON pe.item_id = mi.id AND pe.active = true
     LEFT JOIN menu_extras me ON me.id = pe.extra_id AND me.active = true;;\n\ncreate or replace view public.dashboard_product_metrics as  SELECT mi.id AS item_id,
    mi.name AS product_name,
    mi.slug,
    mi.category_id,
    mc.name AS category_name,
    mis.id AS size_id,
    mis.size_oz,
    mis.size_name,
    COALESCE(pc.total_cost, 0::numeric) AS total_cost,
    pc.ingredient_cost,
    pc.packaging_cost,
    pc.labor_cost,
    pc.overhead_cost,
    pc.waste_cost,
    pc.sale_price,
    pc.minimum_price,
    pc.suggested_price,
    pc.target_margin_percent,
    pc.gross_profit,
    pc.margin_percent,
        CASE
            WHEN pc.total_cost IS NULL THEN 'Sin costo calculado'::text
            WHEN pc.total_cost > 0::numeric AND pc.sale_price IS NOT NULL THEN 'Costo calculado'::text
            ELSE 'Revisar precio'::text
        END AS cost_status
   FROM menu_items mi
     LEFT JOIN menu_categories mc ON mc.id = mi.category_id
     LEFT JOIN menu_item_sizes mis ON mis.item_id = mi.id AND mis.active = true
     LEFT JOIN product_costs pc ON pc.item_id = mi.id AND NOT pc.size_id IS DISTINCT FROM mis.id
  WHERE mi.active = true;;\n\ncreate or replace view public.dashboard_product_sales as  SELECT oi.item_id,
    oi.item_name AS product_name,
    sum(oi.quantity) AS units_sold,
    sum(oi.line_total) AS gross_sales,
    count(DISTINCT oi.order_id) AS orders_count,
    avg(oi.unit_price) AS average_unit_price
   FROM order_items oi
     JOIN orders o ON o.id = oi.order_id
  WHERE o.status = 'completed'::text AND o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) AND o.created_at < (date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) + '1 mon'::interval)
  GROUP BY oi.item_id, oi.item_name;;\n\ncreate or replace view public.dashboard_products_branch as  SELECT oi.item_id,
    oi.item_name AS product_name,
    oi.size_id,
    oi.size_name,
    sum(oi.quantity) AS units_sold,
    round(sum(oi.line_total), 2) AS sales,
    count(DISTINCT oi.order_id) AS orders_count,
    round(avg(oi.unit_price), 2) AS average_unit_price,
    round(sum(oi.line_total - COALESCE(pc.total_cost, 0::numeric) * oi.quantity::numeric), 2) AS estimated_profit
   FROM order_items oi
     JOIN orders o ON o.id = oi.order_id AND o.status = 'completed'::text
     LEFT JOIN product_costs pc ON pc.item_id = oi.item_id AND NOT pc.size_id IS DISTINCT FROM oi.size_id
  GROUP BY oi.item_id, oi.item_name, oi.size_id, oi.size_name;;\n\ncreate or replace view public.dashboard_sales_branch as  SELECT o.id AS order_id,
    o.created_at::date AS sale_date,
    o.created_at,
    COALESCE(o.sales_channel, 'other'::text) AS sales_channel,
    o.customer_id,
    o.payment_method,
    o.subtotal,
    o.discount,
    o.tax,
    o.total,
    count(oi.id) AS line_count,
    COALESCE(sum(oi.quantity), 0::bigint) AS units_sold
   FROM orders o
     LEFT JOIN order_items oi ON oi.order_id = o.id
  WHERE o.status = 'completed'::text
  GROUP BY o.id;;\n\ncreate or replace view public.dashboard_sales_by_channel as  SELECT COALESCE(sales_channel, 'other'::text) AS sales_channel,
    count(*) AS orders_count,
    COALESCE(sum(subtotal - discount), 0::numeric)::numeric(12,2) AS net_sales,
    COALESCE(sum(total), 0::numeric)::numeric(12,2) AS billed_total
   FROM orders
  WHERE status = 'completed'::text AND created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)
  GROUP BY (COALESCE(sales_channel, 'other'::text))
  ORDER BY (COALESCE(sum(subtotal - discount), 0::numeric)::numeric(12,2)) DESC;;\n\ncreate or replace view public.dashboard_sales_by_channel_v2 as  SELECT COALESCE(sales_channel, 'other'::text) AS sales_channel,
    count(id) AS total_orders,
    COALESCE(sum(total), 0::numeric) AS total_sales,
        CASE
            WHEN count(id) > 0 THEN round(sum(total) / count(id)::numeric, 2)
            ELSE 0::numeric
        END AS average_order
   FROM orders o
  WHERE status = 'completed'::text
  GROUP BY (COALESCE(sales_channel, 'other'::text));;\n\ncreate or replace view public.dashboard_sales_progress as  WITH goal AS (
         SELECT COALESCE(( SELECT sg.sales_goal
                   FROM sales_goals sg
                  WHERE sg.goal_month = date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date AND sg.active = true
                  ORDER BY sg.id DESC
                 LIMIT 1), 0::numeric) AS sales_goal
        ), sales AS (
         SELECT COALESCE(sum(o.total) FILTER (WHERE o.status = 'completed'::text), 0::numeric) AS current_sales,
            count(*) FILTER (WHERE o.status = 'completed'::text) AS total_orders
           FROM orders o
          WHERE o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) AND o.created_at < (date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) + '1 mon'::interval)
        )
 SELECT date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date AS goal_month,
    g.sales_goal,
    s.current_sales,
    s.total_orders,
        CASE
            WHEN g.sales_goal > 0::numeric THEN round(s.current_sales / g.sales_goal * 100::numeric, 2)
            ELSE 0::numeric
        END AS progress_percent,
    GREATEST(g.sales_goal - s.current_sales, 0::numeric) AS remaining_to_goal
   FROM goal g
     CROSS JOIN sales s;;\n\ncreate or replace view public.dashboard_summary as  SELECT COALESCE(cs.net_sales, 0::numeric)::numeric(12,2) AS net_sales,
    COALESCE(cs.billed_total, 0::numeric)::numeric(12,2) AS billed_total,
    COALESCE(cs.orders_count, 0::bigint) AS orders_count,
    COALESCE(cs.monthly_goal, 0::numeric)::numeric(12,2) AS monthly_goal,
    COALESCE(cs.goal_progress_percent, 0::numeric)::numeric(12,2) AS goal_progress_percent,
    COALESCE(mp.estimated_product_cost, 0::numeric)::numeric(12,2) AS estimated_product_cost,
    COALESCE(mp.estimated_gross_profit, 0::numeric)::numeric(12,2) AS estimated_gross_profit,
    COALESCE(mp.operating_expenses, 0::numeric)::numeric(12,2) AS operating_expenses,
    COALESCE(mp.payroll, 0::numeric)::numeric(12,2) AS payroll,
    COALESCE(mp.estimated_net_profit, 0::numeric)::numeric(12,2) AS estimated_net_profit,
    COALESCE(mp.estimated_net_margin_percent, 0::numeric)::numeric(12,2) AS estimated_net_margin_percent
   FROM current_sales_dashboard cs
     LEFT JOIN monthly_profitability_dashboard mp ON mp.month = date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date;;\n\ncreate or replace view public.dashboard_summary_v2 as  SELECT COALESCE(sum(
        CASE
            WHEN status = 'completed'::text THEN total
            ELSE 0::numeric
        END), 0::numeric) AS total_sales,
    count(
        CASE
            WHEN status = 'completed'::text THEN id
            ELSE NULL::bigint
        END) AS total_orders,
        CASE
            WHEN count(
            CASE
                WHEN status = 'completed'::text THEN id
                ELSE NULL::bigint
            END) > 0 THEN round(sum(
            CASE
                WHEN status = 'completed'::text THEN total
                ELSE 0::numeric
            END) / count(
            CASE
                WHEN status = 'completed'::text THEN id
                ELSE NULL::bigint
            END)::numeric, 2)
            ELSE 0::numeric
        END AS average_order_value,
    count(
        CASE
            WHEN status = 'completed'::text AND customer_id IS NOT NULL THEN id
            ELSE NULL::bigint
        END) AS orders_with_customer,
    count(
        CASE
            WHEN status = 'completed'::text AND customer_id IS NULL THEN id
            ELSE NULL::bigint
        END) AS orders_without_customer
   FROM orders o;;\n\ncreate or replace view public.dashboard_top_products as  SELECT oi.item_id,
    oi.item_name AS product_name,
    COALESCE(oi.size_name, ''::text) AS size_name,
    sum(oi.quantity) AS units_sold,
    COALESCE(sum(oi.line_total), 0::numeric)::numeric(12,2) AS sales
   FROM order_items oi
     JOIN orders o ON o.id = oi.order_id
  WHERE o.status = 'completed'::text AND o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)
  GROUP BY oi.item_id, oi.item_name, oi.size_name
  ORDER BY (sum(oi.quantity)) DESC, (COALESCE(sum(oi.line_total), 0::numeric)::numeric(12,2)) DESC;;\n\ncreate or replace view public.financial_daily_summary as  WITH days AS (
         SELECT g.d::date AS day
           FROM generate_series(COALESCE(( SELECT min(orders.created_at)::date AS min
                   FROM orders), CURRENT_DATE)::timestamp with time zone, GREATEST(CURRENT_DATE, COALESCE(( SELECT max(orders.created_at)::date AS max
                   FROM orders), CURRENT_DATE), COALESCE(( SELECT max(business_expenses.expense_date) AS max
                   FROM business_expenses), CURRENT_DATE), COALESCE(( SELECT max(payroll_entries.work_date) AS max
                   FROM payroll_entries), CURRENT_DATE))::timestamp with time zone, '1 day'::interval) g(d)
        ), sales AS (
         SELECT o.created_at::date AS day,
            COALESCE(sum(o.total) FILTER (WHERE o.status = 'completed'::text), 0::numeric)::numeric(12,2) AS sales_total,
            COALESCE(sum(o.discount) FILTER (WHERE o.status = 'completed'::text), 0::numeric)::numeric(12,2) AS discounts
           FROM orders o
          GROUP BY (o.created_at::date)
        ), costs AS (
         SELECT o.created_at::date AS day,
            COALESCE(sum(
                CASE
                    WHEN o.status = 'completed'::text THEN oi.quantity::numeric * COALESCE(pc.total_cost, 0::numeric)
                    ELSE 0::numeric
                END), 0::numeric)::numeric(12,2) AS product_cost_total
           FROM orders o
             JOIN order_items oi ON oi.order_id = o.id
             LEFT JOIN LATERAL ( SELECT pc_1.total_cost
                   FROM product_costs pc_1
                  WHERE pc_1.item_id = oi.item_id AND (pc_1.size_id = oi.size_id OR pc_1.size_id IS NULL AND oi.size_id IS NULL)
                  ORDER BY pc_1.calculated_at DESC, pc_1.id DESC
                 LIMIT 1) pc ON true
          GROUP BY (o.created_at::date)
        ), payroll AS (
         SELECT payroll_entries.work_date AS day,
            COALESCE(sum(payroll_entries.gross_pay), 0::numeric)::numeric(12,2) AS payroll_total
           FROM payroll_entries
          GROUP BY payroll_entries.work_date
        ), expenses AS (
         SELECT business_expenses.expense_date AS day,
            COALESCE(sum(business_expenses.amount), 0::numeric)::numeric(12,2) AS expenses_total
           FROM business_expenses
          GROUP BY business_expenses.expense_date
        )
 SELECT d.day,
    COALESCE(s.sales_total, 0::numeric)::numeric(12,2) AS sales_total,
    COALESCE(s.discounts, 0::numeric)::numeric(12,2) AS discounts,
    COALESCE(c.product_cost_total, 0::numeric)::numeric(12,2) AS product_cost_total,
    COALESCE(p.payroll_total, 0::numeric)::numeric(12,2) AS payroll_total,
    COALESCE(e.expenses_total, 0::numeric)::numeric(12,2) AS expenses_total,
    (COALESCE(s.sales_total, 0::numeric) - COALESCE(c.product_cost_total, 0::numeric) - COALESCE(p.payroll_total, 0::numeric) - COALESCE(e.expenses_total, 0::numeric))::numeric(12,2) AS estimated_net
   FROM days d
     LEFT JOIN sales s ON s.day = d.day
     LEFT JOIN costs c ON c.day = d.day
     LEFT JOIN payroll p ON p.day = d.day
     LEFT JOIN expenses e ON e.day = d.day
  ORDER BY d.day DESC;;\n\ncreate or replace view public.inventory_movement_summary as  SELECT im.id,
    im.ingredient_id,
    i.name AS ingredient,
    i.unit,
    im.movement_type,
    im.quantity,
    im.unit_cost,
    im.production_batch_id,
    im.reference_type,
    im.reference_id,
    im.notes,
    im.created_at
   FROM inventory_movements im
     JOIN ingredients i ON i.id = im.ingredient_id;;\n\ncreate or replace view public.inventory_status as  SELECT id AS ingredient_id,
    name,
    unit,
    current_quantity,
    minimum_quantity,
    cost_per_unit,
    current_quantity <= minimum_quantity AS low_stock,
    active,
    updated_at
   FROM ingredients i;;\n\ncreate or replace view public.menu_channel_price_admin as  SELECT mi.id AS item_id,
    mi.name AS item_name,
    mi.has_sizes,
    mi.base_price AS store_base_price,
    mis.id AS size_id,
    mis.size_oz,
    mis.size_name,
        CASE
            WHEN mis.id IS NULL THEN mi.base_price
            ELSE mis.price
        END AS store_price,
    mcp.id AS doordash_price_id,
    mcp.price AS doordash_price,
    COALESCE(mcp.active, true) AS doordash_active,
    mcp.updated_at AS doordash_updated_at
   FROM menu_items mi
     LEFT JOIN menu_item_sizes mis ON mis.item_id = mi.id AND mis.active = true
     LEFT JOIN menu_channel_prices mcp ON mcp.item_id = mi.id AND NOT mcp.size_id IS DISTINCT FROM mis.id AND mcp.channel = 'doordash'::text
  WHERE mi.active = true;;\n\ncreate or replace view public.metas_actual as  WITH sales AS (
         SELECT sg_1.id AS goal_id,
            COALESCE(sum(o.total), 0::numeric) AS sales_to_date
           FROM sales_goals sg_1
             LEFT JOIN orders o ON o.status = 'completed'::text AND o.created_at >= sg_1.goal_month AND o.created_at < (sg_1.goal_month + '1 mon'::interval)
          WHERE sg_1.goal_month = date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date AND sg_1.active = true
          GROUP BY sg_1.id
        )
 SELECT sg.id,
    sg.goal_month,
    sg.sales_goal,
    sg.notes,
    sg.active,
    s.sales_to_date,
        CASE
            WHEN sg.sales_goal > 0::numeric THEN round(s.sales_to_date / sg.sales_goal * 100::numeric, 2)
            ELSE 0::numeric
        END AS progress_percent
   FROM sales_goals sg
     JOIN sales s ON s.goal_id = sg.id
  WHERE sg.goal_month = date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date AND sg.active = true;;\n\ncreate or replace view public.monthly_expense_summary as  SELECT date_trunc('month'::text, expense_date::timestamp with time zone)::date AS month,
    category,
    count(*) AS expense_count,
    sum(amount) AS total_expenses
   FROM business_expenses
  GROUP BY (date_trunc('month'::text, expense_date::timestamp with time zone)::date), category;;\n\ncreate or replace view public.monthly_payroll_summary as  SELECT date_trunc('month'::text, work_date::timestamp with time zone)::date AS month,
    count(*) AS payroll_entries,
    sum(hours) AS total_hours,
    sum(gross_pay) AS total_payroll
   FROM payroll_entries
  GROUP BY (date_trunc('month'::text, work_date::timestamp with time zone)::date);;\n\ncreate or replace view public.monthly_profitability_dashboard as  WITH months AS (
         SELECT generate_series(date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) - '11 mons'::interval, date_trunc('month'::text, CURRENT_DATE::timestamp with time zone), '1 mon'::interval)::date AS month
        ), sales AS (
         SELECT monthly_sales_dashboard.month,
            monthly_sales_dashboard.net_sales,
            monthly_sales_dashboard.estimated_product_cost,
            monthly_sales_dashboard.estimated_gross_profit
           FROM monthly_sales_dashboard
        ), expenses AS (
         SELECT date_trunc('month'::text, business_expenses.expense_date::timestamp with time zone)::date AS month,
            sum(business_expenses.amount) AS total_expenses
           FROM business_expenses
          GROUP BY (date_trunc('month'::text, business_expenses.expense_date::timestamp with time zone)::date)
        ), payroll AS (
         SELECT date_trunc('month'::text, payroll_entries.work_date::timestamp with time zone)::date AS month,
            sum(payroll_entries.gross_pay) AS total_payroll
           FROM payroll_entries
          GROUP BY (date_trunc('month'::text, payroll_entries.work_date::timestamp with time zone)::date)
        )
 SELECT m.month,
    COALESCE(s.net_sales, 0::numeric) AS net_sales,
    COALESCE(s.estimated_product_cost, 0::numeric) AS estimated_product_cost,
    COALESCE(s.estimated_gross_profit, 0::numeric) AS estimated_gross_profit,
    COALESCE(e.total_expenses, 0::numeric) AS operating_expenses,
    COALESCE(p.total_payroll, 0::numeric) AS payroll,
    COALESCE(s.estimated_gross_profit, 0::numeric) - COALESCE(e.total_expenses, 0::numeric) - COALESCE(p.total_payroll, 0::numeric) AS estimated_net_profit,
        CASE
            WHEN COALESCE(s.net_sales, 0::numeric) > 0::numeric THEN round((COALESCE(s.estimated_gross_profit, 0::numeric) - COALESCE(e.total_expenses, 0::numeric) - COALESCE(p.total_payroll, 0::numeric)) / s.net_sales * 100::numeric, 2)
            ELSE 0::numeric
        END AS estimated_net_margin_percent
   FROM months m
     LEFT JOIN sales s ON s.month = m.month
     LEFT JOIN expenses e ON e.month = m.month
     LEFT JOIN payroll p ON p.month = m.month
  ORDER BY m.month DESC;;\n\ncreate or replace view public.monthly_sales_dashboard as  SELECT date_trunc('month'::text, o.created_at)::date AS month,
    count(DISTINCT o.id) AS orders_count,
    round(sum(o.subtotal), 2) AS gross_sales,
    round(sum(o.discount), 2) AS discounts,
    round(sum(o.subtotal - o.discount), 2) AS net_sales,
    round(sum(o.tax), 2) AS tax_collected,
    round(sum(o.total), 2) AS billed_total,
    round(COALESCE(sum(oi_cost.estimated_cost), 0::numeric), 2) AS estimated_product_cost,
    round(sum(o.subtotal - o.discount) - COALESCE(sum(oi_cost.estimated_cost), 0::numeric), 2) AS estimated_gross_profit,
        CASE
            WHEN sum(o.subtotal - o.discount) > 0::numeric THEN round(100::numeric * (sum(o.subtotal - o.discount) - COALESCE(sum(oi_cost.estimated_cost), 0::numeric)) / sum(o.subtotal - o.discount), 2)
            ELSE 0::numeric
        END AS estimated_margin_percent,
    max(sg.sales_goal) AS monthly_goal,
        CASE
            WHEN max(sg.sales_goal) > 0::numeric THEN round(100::numeric * sum(o.subtotal - o.discount) / max(sg.sales_goal), 2)
            ELSE NULL::numeric
        END AS goal_progress_percent
   FROM orders o
     JOIN ( SELECT oi.order_id,
            sum(oi.quantity::numeric * COALESCE(pc.total_cost, 0::numeric)) AS estimated_cost
           FROM order_items oi
             LEFT JOIN product_costs pc ON pc.item_id = oi.item_id AND NOT pc.size_id IS DISTINCT FROM oi.size_id
          GROUP BY oi.order_id) oi_cost ON oi_cost.order_id = o.id
     LEFT JOIN sales_goals sg ON sg.goal_month = date_trunc('month'::text, o.created_at)::date
  WHERE o.status = 'completed'::text
  GROUP BY (date_trunc('month'::text, o.created_at)::date);;\n\ncreate or replace view public.product_customization_summary as  SELECT pe.item_id,
    mi.name AS product,
    pe.extra_id,
    me.name AS extra,
    me.group_name,
    me.price,
    pe.active,
    pe.sort_order
   FROM product_extras pe
     JOIN menu_items mi ON mi.id = pe.item_id
     JOIN menu_extras me ON me.id = pe.extra_id;;\n\ncreate or replace view public.product_pricing_summary as  SELECT pc.id AS product_cost_id,
    pc.item_id,
    mi.name AS product,
    pc.size_id,
    COALESCE(mis.size_name,
        CASE
            WHEN mis.size_oz IS NOT NULL THEN mis.size_oz::text || ' oz'::text
            ELSE NULL::text
        END) AS size_name,
    pc.total_cost,
    pc.sale_price AS current_price,
    pc.minimum_price,
    pc.suggested_price,
    pc.gross_profit,
    pc.margin_percent,
    pc.target_margin_percent,
    pc.calculated_at
   FROM product_costs pc
     JOIN menu_items mi ON mi.id = pc.item_id
     LEFT JOIN menu_item_sizes mis ON mis.id = pc.size_id;;\n\ncreate or replace view public.product_sales_summary as  SELECT oi.item_id,
    oi.size_id,
    oi.item_name AS product,
    oi.size_name,
    sum(oi.quantity) AS units_sold,
    round(sum(oi.line_total), 2) AS sales,
    round(sum(oi.line_total - COALESCE(pc.total_cost, 0::numeric) * oi.quantity::numeric), 2) AS estimated_profit,
        CASE
            WHEN sum(oi.line_total) > 0::numeric THEN round(100::numeric * sum(oi.line_total - COALESCE(pc.total_cost, 0::numeric) * oi.quantity::numeric) / sum(oi.line_total), 2)
            ELSE 0::numeric
        END AS estimated_margin_percent,
    count(DISTINCT oi.order_id) AS orders_count
   FROM order_items oi
     JOIN orders o ON o.id = oi.order_id AND o.status = 'completed'::text
     LEFT JOIN product_costs pc ON pc.item_id = oi.item_id AND NOT pc.size_id IS DISTINCT FROM oi.size_id
  GROUP BY oi.item_id, oi.size_id, oi.item_name, oi.size_name;;\n\ncreate or replace view public.production_batch_summary as  SELECT pb.id,
    pb.item_id,
    mi.name AS product,
    pb.recipe_id,
    r.name AS recipe,
    pb.size_id,
    COALESCE(mis.size_name,
        CASE
            WHEN mis.size_oz IS NOT NULL THEN mis.size_oz::text || ' oz'::text
            ELSE NULL::text
        END) AS size_name,
    pb.quantity_produced,
    pb.unit,
    pb.total_cost,
    pb.cost_per_unit,
    pb.waste_quantity,
    pb.status,
    pb.produced_at,
    pb.notes
   FROM production_batches pb
     JOIN menu_items mi ON mi.id = pb.item_id
     LEFT JOIN recipes r ON r.id = pb.recipe_id
     LEFT JOIN menu_item_sizes mis ON mis.id = pb.size_id;;\n\ncreate or replace view public.productos_metricas as  SELECT mi.id AS item_id,
    mi.name AS product_name,
    mc.name AS category_name,
    mi.active,
    mi.featured,
    mi.seasonal,
    mi.has_sizes,
    mi.base_price,
    pc.total_cost AS product_cost,
    pc.minimum_price,
    pc.suggested_price,
    pc.target_margin_percent,
        CASE
            WHEN pc.total_cost IS NOT NULL AND COALESCE(pc.minimum_price, 0::numeric) > 0::numeric THEN pc.minimum_price - pc.total_cost
            ELSE NULL::numeric
        END AS minimum_profit,
        CASE
            WHEN pc.total_cost IS NOT NULL AND COALESCE(pc.suggested_price, 0::numeric) > 0::numeric THEN pc.suggested_price - pc.total_cost
            ELSE NULL::numeric
        END AS suggested_profit,
        CASE
            WHEN pc.total_cost IS NOT NULL AND COALESCE(pc.suggested_price, 0::numeric) > 0::numeric THEN round((pc.suggested_price - pc.total_cost) / pc.suggested_price * 100::numeric, 2)
            ELSE NULL::numeric
        END AS estimated_margin_percent
   FROM menu_items mi
     LEFT JOIN menu_categories mc ON mc.id = mi.category_id
     LEFT JOIN product_costs pc ON pc.item_id = mi.id
  WHERE mi.active = true;;\n\ncreate or replace view public.productos_precios_por_canal as  SELECT mi.id AS item_id,
    mi.name AS product_name,
    mis.id AS size_id,
    mis.size_name,
    mis.size_oz,
    COALESCE(mcp_store.price, mis.price) AS store_price,
    mcp_doordash.price AS doordash_price,
    mcp_other.price AS other_price
   FROM menu_items mi
     LEFT JOIN menu_item_sizes mis ON mis.item_id = mi.id AND mis.active = true
     LEFT JOIN menu_channel_prices mcp_store ON mcp_store.item_id = mi.id AND (mcp_store.size_id = mis.id OR mcp_store.size_id IS NULL AND mis.id IS NULL) AND mcp_store.channel = 'store'::text AND mcp_store.active = true
     LEFT JOIN menu_channel_prices mcp_doordash ON mcp_doordash.item_id = mi.id AND (mcp_doordash.size_id = mis.id OR mcp_doordash.size_id IS NULL AND mis.id IS NULL) AND mcp_doordash.channel = 'doordash'::text AND mcp_doordash.active = true
     LEFT JOIN menu_channel_prices mcp_other ON mcp_other.item_id = mi.id AND (mcp_other.size_id = mis.id OR mcp_other.size_id IS NULL AND mis.id IS NULL) AND mcp_other.channel = 'other'::text AND mcp_other.active = true
  WHERE mi.active = true;;\n\ncreate or replace view public.recipe_cost_summary as  SELECT r.id AS recipe_id,
    r.item_id,
    mi.name AS product,
    r.size_id,
    COALESCE(mis.size_name,
        CASE
            WHEN mis.size_oz IS NOT NULL THEN mis.size_oz::text || ' oz'::text
            ELSE NULL::text
        END) AS size_name,
    r.name AS recipe,
    r.version,
    r.yield_quantity,
    r.yield_unit,
    round(COALESCE(sum(ri.quantity * i.cost_per_unit), 0::numeric), 4) AS ingredient_cost,
    round(COALESCE(sum(ri.quantity * i.cost_per_unit), 0::numeric) / r.yield_quantity, 4) AS cost_per_yield_unit,
    r.active,
    r.updated_at
   FROM recipes r
     JOIN menu_items mi ON mi.id = r.item_id
     LEFT JOIN menu_item_sizes mis ON mis.id = r.size_id
     LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.id
     LEFT JOIN ingredients i ON i.id = ri.ingredient_id
  GROUP BY r.id, r.item_id, mi.name, r.size_id, mis.size_name, mis.size_oz, r.name, r.version, r.yield_quantity, r.yield_unit, r.active, r.updated_at;;\n\ncreate or replace view public.sales_goal_dashboard as  WITH months AS (
         SELECT generate_series(date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) - '11 mons'::interval, date_trunc('month'::text, CURRENT_DATE::timestamp with time zone), '1 mon'::interval)::date AS month
        ), sales AS (
         SELECT date_trunc('month'::text, o.created_at)::date AS month,
            COALESCE(sum(o.subtotal - o.discount), 0::numeric) AS net_sales,
            COALESCE(sum(o.total), 0::numeric) AS billed_total,
            count(DISTINCT o.id) AS orders_count
           FROM orders o
          WHERE o.status = 'completed'::text
          GROUP BY (date_trunc('month'::text, o.created_at)::date)
        ), goals AS (
         SELECT sales_goals.goal_month AS month,
            sales_goals.sales_goal
           FROM sales_goals
          WHERE sales_goals.active = true
        )
 SELECT m.month,
    COALESCE(g.sales_goal, 0::numeric)::numeric(12,2) AS monthly_goal,
    round(COALESCE(s.net_sales, 0::numeric), 2) AS net_sales,
    round(COALESCE(s.billed_total, 0::numeric), 2) AS billed_total,
    COALESCE(s.orders_count, 0::bigint) AS orders_count,
        CASE
            WHEN COALESCE(g.sales_goal, 0::numeric) > 0::numeric THEN round(COALESCE(s.net_sales, 0::numeric) / g.sales_goal * 100::numeric, 2)
            ELSE 0::numeric
        END AS goal_progress_percent,
    round(GREATEST(COALESCE(g.sales_goal, 0::numeric) - COALESCE(s.net_sales, 0::numeric), 0::numeric), 2) AS remaining_to_goal
   FROM months m
     LEFT JOIN sales s USING (month)
     LEFT JOIN goals g USING (month)
  ORDER BY m.month DESC;;\n\ncreate or replace view public.ventas_avance_mensual as  WITH goal AS (
         SELECT sg.sales_goal
           FROM sales_goals sg
          WHERE sg.goal_month = date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date AND sg.active = true
         LIMIT 1
        )
 SELECT date_trunc('month'::text, CURRENT_DATE::timestamp with time zone)::date AS goal_month,
    COALESCE(g.sales_goal, 0::numeric) AS sales_goal,
    COALESCE(sum(o.total), 0::numeric) AS current_sales,
        CASE
            WHEN COALESCE(g.sales_goal, 0::numeric) > 0::numeric THEN round(sum(o.total) / g.sales_goal * 100::numeric, 2)
            ELSE 0::numeric
        END AS goal_progress_percent,
    count(o.id) AS total_orders
   FROM orders o
     CROSS JOIN goal g
  WHERE o.status = 'completed'::text AND o.created_at >= date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) AND o.created_at < (date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) + '1 mon'::interval)
  GROUP BY g.sales_goal;;\n\ncreate or replace view public.ventas_por_producto as  SELECT oi.item_id,
    oi.item_name,
    sum(oi.quantity) AS units_sold,
    sum(oi.line_total) AS sales_amount,
    pc.total_cost AS unit_cost,
        CASE
            WHEN pc.total_cost IS NOT NULL THEN sum(oi.quantity)::numeric * pc.total_cost
            ELSE NULL::numeric
        END AS estimated_product_cost,
        CASE
            WHEN pc.total_cost IS NOT NULL THEN sum(oi.line_total) - sum(oi.quantity)::numeric * pc.total_cost
            ELSE NULL::numeric
        END AS estimated_gross_profit
   FROM order_items oi
     JOIN orders o ON o.id = oi.order_id
     LEFT JOIN product_costs pc ON pc.item_id = oi.item_id
  WHERE o.status = 'completed'::text
  GROUP BY oi.item_id, oi.item_name, pc.total_cost;;