-- LIVE SUPABASE SCHEMA — FUNCTIONS\n\nCREATE OR REPLACE FUNCTION public.add_loyalty_stamp(p_customer_id uuid, p_amount numeric)
 RETURNS loyalty_cards
 LANGUAGE plpgsql
 SET search_path TO 'public', 'private'
AS $function$
declare
  v_card public.loyalty_cards;
begin
  if not private.is_menu_admin() then
    raise exception 'No autorizado';
  end if;

  if p_customer_id is null or p_amount is null or p_amount < 8 then
    return null;
  end if;

  if not exists (
    select 1 from public.loyalty_cards where customer_id=p_customer_id
  ) then
    return null;
  end if;

  perform public.register_purchase(p_customer_id,p_amount);

  select * into v_card
  from public.loyalty_cards
  where customer_id=p_customer_id;

  return v_card;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.register_purchase(p_customer_id uuid, p_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_stamps integer;
  v_cycle integer;
  v_stamp_earned integer := 0;
  v_reward text := null;
  v_recent_order_id bigint;
  v_recent_order_amount numeric;
  v_recent_stamp_earned integer;
begin
  if p_customer_id is null then
    return jsonb_build_object('success',true,'processed',false,'reason','no_customer');
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'El monto de la compra debe ser mayor que 0';
  end if;

  select stamps, cycle_number into v_stamps, v_cycle
  from public.loyalty_cards
  where customer_id = p_customer_id
  for update;

  if not found then
    return jsonb_build_object(
      'success', true,
      'processed', false,
      'reason', 'no_loyalty_card',
      'customer_id', p_customer_id,
      'purchase_amount', p_amount
    );
  end if;

  select o.id, st.amount, st.stamps_earned
    into v_recent_order_id, v_recent_order_amount, v_recent_stamp_earned
  from public.orders o
  join public.stamp_transactions st on st.order_id = o.id
  where o.customer_id = p_customer_id
    and o.status = 'completed'
    and o.created_at >= now() - interval '2 minutes'
  order by o.created_at desc
  limit 1;

  if v_recent_order_id is not null then
    return jsonb_build_object(
      'success', true,
      'processed', false,
      'reason', 'order_loyalty_already_processed',
      'order_id', v_recent_order_id,
      'customer_id', p_customer_id,
      'purchase_amount', v_recent_order_amount,
      'stamp_earned', v_recent_stamp_earned,
      'stamps', v_stamps,
      'cycle_number', v_cycle,
      'reward_created', null
    );
  end if;

  if p_amount >= 8 and v_stamps < 10 then
    v_stamp_earned := 1;
  end if;

  insert into public.stamp_transactions(customer_id, amount, stamps_earned)
  values (p_customer_id, p_amount, v_stamp_earned);

  if v_stamp_earned = 1 then
    v_stamps := v_stamps + 1;

    update public.loyalty_cards
    set stamps = v_stamps,
        reward_available = (v_stamps >= 10)
    where customer_id = p_customer_id;

    if v_stamps = 5 then
      insert into public.loyalty_rewards
        (customer_id, cycle_number, reward_type, status, amount, description)
      values
        (p_customer_id, v_cycle, 'five_stamp_discount', 'available', 2.00, '$2 OFF')
      on conflict (customer_id, cycle_number, reward_type) do nothing;
      v_reward := '$2 OFF';
    end if;

    if v_stamps = 10 then
      insert into public.loyalty_rewards
        (customer_id, cycle_number, reward_type, status, amount, description)
      values
        (p_customer_id, v_cycle, 'ten_stamp_free_product', 'available', null,
         'Recompensa de 10 sellos — producto gratis')
      on conflict (customer_id, cycle_number, reward_type) do nothing;
      v_reward := 'Recompensa de 10 sellos — producto gratis';
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'processed', true,
    'customer_id', p_customer_id,
    'purchase_amount', p_amount,
    'stamp_earned', v_stamp_earned,
    'stamps', v_stamps,
    'cycle_number', v_cycle,
    'reward_created', v_reward
  );
end;
$function$

\nCREATE OR REPLACE FUNCTION public.redeem_reward(p_reward_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_customer_id uuid;
  v_cycle integer;
  v_reward_type text;
  v_status text;
begin
  if not private.is_menu_admin() then
    raise exception 'No autorizado';
  end if;

  select customer_id,cycle_number,reward_type,status
  into v_customer_id,v_cycle,v_reward_type,v_status
  from public.loyalty_rewards
  where id=p_reward_id
  for update;

  if not found then raise exception 'La recompensa no existe'; end if;
  if v_status <> 'available' then
    raise exception 'Esta recompensa ya fue canjeada o no está disponible';
  end if;

  update public.loyalty_rewards
  set status='redeemed',redeemed_at=now()
  where id=p_reward_id;

  if v_reward_type='ten_stamp_free_product' then
    update public.loyalty_rewards
    set status='expired'
    where customer_id=v_customer_id
      and cycle_number=v_cycle
      and status='available'
      and id<>p_reward_id;

    update public.loyalty_cards
    set stamps=0,reward_available=false,cycle_number=cycle_number+1
    where customer_id=v_customer_id;

    return jsonb_build_object(
      'success',true,'reward_type',v_reward_type,
      'customer_id',v_customer_id,'previous_cycle',v_cycle,
      'new_cycle',v_cycle+1,'stamps',0,
      'message','Recompensa de 10 sellos canjeada. Nuevo ciclo iniciado.'
    );
  end if;

  if v_reward_type='five_stamp_discount' then
    return jsonb_build_object(
      'success',true,'reward_type',v_reward_type,
      'customer_id',v_customer_id,'message','$2 OFF canjeado'
    );
  end if;

  raise exception 'Tipo de recompensa no reconocido';
end;
$function$

\nCREATE OR REPLACE FUNCTION public.receipts_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.register_order_loyalty(p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_customer_id uuid;
  v_amount numeric;
  v_status text;
  v_stamps integer;
  v_cycle integer;
  v_stamp_earned integer := 0;
  v_reward text := null;
begin
  select customer_id, subtotal, status
    into v_customer_id, v_amount, v_status
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'La orden no existe';
  end if;

  if v_status <> 'completed' then
    return jsonb_build_object('success', true, 'processed', false, 'reason', 'order_not_completed');
  end if;

  if v_customer_id is null then
    return jsonb_build_object('success', true, 'processed', false, 'reason', 'no_customer');
  end if;

  if exists (
    select 1 from public.stamp_transactions
    where order_id = p_order_id
  ) then
    return jsonb_build_object('success', true, 'processed', false, 'reason', 'already_processed');
  end if;

  select stamps, cycle_number
    into v_stamps, v_cycle
  from public.loyalty_cards
  where customer_id = v_customer_id
  for update;

  if not found then
    return jsonb_build_object('success', true, 'processed', false, 'reason', 'no_loyalty_card');
  end if;

  if v_amount is null or v_amount <= 0 then
    return jsonb_build_object('success', true, 'processed', false, 'reason', 'invalid_amount');
  end if;

  if v_amount >= 8 and v_stamps < 10 then
    v_stamp_earned := 1;
  end if;

  insert into public.stamp_transactions
    (order_id, customer_id, amount, stamps_earned)
  values
    (p_order_id, v_customer_id, v_amount, v_stamp_earned);

  if v_stamp_earned = 1 then
    v_stamps := v_stamps + 1;

    update public.loyalty_cards
    set stamps = v_stamps,
        reward_available = (v_stamps >= 10)
    where customer_id = v_customer_id;

    if v_stamps = 5 then
      insert into public.loyalty_rewards
        (customer_id, cycle_number, reward_type, status, amount, description)
      values
        (v_customer_id, v_cycle, 'five_stamp_discount', 'available', 2.00, '$2 OFF')
      on conflict (customer_id, cycle_number, reward_type) do nothing;
      v_reward := '$2 OFF';
    end if;

    if v_stamps = 10 then
      insert into public.loyalty_rewards
        (customer_id, cycle_number, reward_type, status, amount, description)
      values
        (v_customer_id, v_cycle, 'ten_stamp_free_product', 'available', null,
         'Recompensa de 10 sellos — producto gratis')
      on conflict (customer_id, cycle_number, reward_type) do nothing;
      v_reward := 'Recompensa de 10 sellos — producto gratis';
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'processed', true,
    'order_id', p_order_id,
    'customer_id', v_customer_id,
    'purchase_amount', v_amount,
    'stamp_earned', v_stamp_earned,
    'stamps', v_stamps,
    'cycle_number', v_cycle,
    'reward_created', v_reward
  );
end;
$function$

\nCREATE OR REPLACE FUNCTION public.orders_apply_loyalty()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status = 'completed'
     AND (
       TG_OP = 'INSERT'
       OR OLD.status IS DISTINCT FROM 'completed'
     )
  THEN
    PERFORM public.register_order_loyalty(NEW.id);
  END IF;

  RETURN NEW;
END;
$function$

\nCREATE OR REPLACE FUNCTION public.orders_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.menu_channel_prices_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.get_menu_price(p_item_id bigint, p_size_id bigint DEFAULT NULL::bigint, p_channel text DEFAULT 'store'::text)
 RETURNS numeric
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_price numeric;
begin
  if p_channel not in ('store','doordash','other') then
    raise exception 'Canal inválido: %', p_channel;
  end if;

  if p_size_id is not null then
    select mcp.price
      into v_price
      from public.menu_channel_prices mcp
     where mcp.item_id = p_item_id
       and mcp.size_id = p_size_id
       and mcp.channel = p_channel
       and mcp.active = true
     limit 1;

    if v_price is not null then
      return v_price;
    end if;

    if p_channel <> 'store' then
      return null;
    end if;

    select mis.price
      into v_price
      from public.menu_item_sizes mis
     where mis.id = p_size_id
       and mis.item_id = p_item_id
       and mis.active = true
     limit 1;

    return v_price;
  end if;

  select mcp.price
    into v_price
    from public.menu_channel_prices mcp
   where mcp.item_id = p_item_id
     and mcp.size_id is null
     and mcp.channel = p_channel
     and mcp.active = true
   limit 1;

  if v_price is not null then
    return v_price;
  end if;

  if p_channel <> 'store' then
    return null;
  end if;

  select mi.base_price
    into v_price
    from public.menu_items mi
   where mi.id = p_item_id
     and mi.active = true;

  return v_price;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.calculate_order_totals(p_order_id bigint, p_discount_type text DEFAULT NULL::text, p_discount_value numeric DEFAULT NULL::numeric, p_apply_state_tax boolean DEFAULT true, p_apply_municipal_tax boolean DEFAULT true)
 RETURNS orders
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_order public.orders%rowtype;
  v_subtotal numeric(12,2);
  v_discount numeric(12,2) := 0;
  v_taxable numeric(12,2);
  v_state_rate numeric(8,4) := 0;
  v_municipal_rate numeric(8,4) := 0;
  v_state_tax numeric(12,2) := 0;
  v_municipal_tax numeric(12,2) := 0;
  v_discount_type text;
  v_discount_value numeric := 0;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then raise exception 'Order % not found', p_order_id; end if;

  select coalesce(sum(line_total), 0)::numeric(12,2)
  into v_subtotal
  from public.order_items where order_id = p_order_id;

  v_discount_type := coalesce(p_discount_type, v_order.discount_type, 'fixed');
  v_discount_value := greatest(coalesce(p_discount_value, v_order.discount_value, 0), 0);

  if v_discount_type = 'percent' then
    v_discount := round(least(v_discount_value, 100) * v_subtotal / 100, 2);
  elsif v_discount_type = 'fixed' then
    v_discount := round(least(v_discount_value, v_subtotal), 2);
  else
    raise exception 'Invalid discount type: %', v_discount_type;
  end if;

  v_taxable := greatest(v_subtotal - v_discount, 0);

  if p_apply_state_tax then
    select coalesce(max(rate), 0) into v_state_rate
    from public.tax_rates where code='ivu_estatal_pr' and active=true;
  end if;
  if p_apply_municipal_tax then
    select coalesce(max(rate), 0) into v_municipal_rate
    from public.tax_rates where code='ivu_municipal_bayamon' and active=true;
  end if;

  v_state_tax := round(v_taxable * v_state_rate / 100, 2);
  v_municipal_tax := round(v_taxable * v_municipal_rate / 100, 2);

  update public.orders
  set subtotal=v_subtotal,
      discount_type=v_discount_type,
      discount_value=v_discount_value,
      discount=v_discount,
      tax_rate=v_state_rate+v_municipal_rate,
      tax_state=v_state_tax,
      tax_municipal=v_municipal_tax,
      tax=v_state_tax+v_municipal_tax,
      total=v_taxable+v_state_tax+v_municipal_tax,
      updated_at=now()
  where id=p_order_id
  returning * into v_order;

  return v_order;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.create_sale_receipt(p_order_id bigint)
 RETURNS receipts
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_order public.orders%rowtype;
  v_receipt public.receipts%rowtype;
begin
  select * into v_order from public.orders where id=p_order_id;
  if not found then
    raise exception 'Order % not found', p_order_id;
  end if;

  if v_order.status <> 'completed' then
    raise exception 'Order % must be completed before creating a receipt', p_order_id;
  end if;

  select * into v_receipt
  from public.receipts
  where order_id=p_order_id and receipt_type='sale'
  order by id desc
  limit 1;

  if found then
    return v_receipt;
  end if;

  insert into public.receipts
    (receipt_type, receipt_date, vendor, amount, order_id, notes)
  values
    ('sale', v_order.created_at::date, 'B Fresas Lovers', v_order.total, p_order_id,
     concat('Recibo de venta #', p_order_id))
  returning * into v_receipt;

  return v_receipt;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.calculate_product_cost(p_item_id bigint, p_size_id bigint DEFAULT NULL::bigint, p_packaging_cost numeric DEFAULT 0, p_labor_cost numeric DEFAULT 0, p_overhead_cost numeric DEFAULT 0, p_sale_price numeric DEFAULT 0, p_target_margin_percent numeric DEFAULT 0)
 RETURNS product_costs
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
 v_cost public.product_costs%rowtype;
 v_ingredient_cost numeric(12,4);
 v_waste_percent numeric(12,4);
 v_waste_cost numeric(12,4);
 v_total numeric(12,4);
 v_profit numeric(12,4);
 v_margin numeric(12,4);
 v_min_price numeric(12,4);
 v_suggested_price numeric(12,4);
begin
 if not exists (select 1 from public.menu_items where id=p_item_id) then
   raise exception 'Menu item % not found',p_item_id;
 end if;
 if coalesce(p_target_margin_percent,0) < 0 or coalesce(p_target_margin_percent,0) >= 100 then
   raise exception 'El margen objetivo debe estar entre 0 y menos de 100';
 end if;

 select coalesce(sum(ri.quantity*i.cost_per_unit),0)
 into v_ingredient_cost
 from public.recipes r
 join public.recipe_ingredients ri on ri.recipe_id=r.id
 join public.ingredients i on i.id=ri.ingredient_id and i.active=true
 where r.item_id=p_item_id and r.active=true
   and r.size_id is not distinct from p_size_id;

 if not exists (
   select 1 from public.recipes r
   where r.item_id=p_item_id and r.active=true
     and r.size_id is not distinct from p_size_id
 ) then
   select coalesce(sum(pi.quantity*i.cost_per_unit),0)
   into v_ingredient_cost
   from public.product_ingredients pi
   join public.ingredients i on i.id=pi.ingredient_id and i.active=true
   where pi.item_id=p_item_id;
 end if;

 select coalesce(max(value),0) into v_waste_percent
 from public.cost_settings where code='waste_percent' and active=true;

 v_waste_cost:=round(v_ingredient_cost*v_waste_percent/100,4);
 v_total:=round(v_ingredient_cost+coalesce(p_packaging_cost,0)+coalesce(p_labor_cost,0)+coalesce(p_overhead_cost,0)+v_waste_cost,4);
 v_profit:=round(coalesce(p_sale_price,0)-v_total,4);
 v_margin:=case when coalesce(p_sale_price,0)>0 then round(v_profit/p_sale_price*100,4) else 0 end;

 v_min_price:=case
   when coalesce(p_target_margin_percent,0)>0
   then round(v_total/(1-p_target_margin_percent/100),2)
   else v_total
 end;

 v_suggested_price:=case
   when coalesce(p_target_margin_percent,0)>0 then v_min_price
   else round(v_total*2,2)
 end;

 insert into public.product_costs
 (item_id,size_id,ingredient_cost,packaging_cost,labor_cost,overhead_cost,waste_cost,total_cost,sale_price,gross_profit,margin_percent,target_margin_percent,minimum_price,suggested_price,calculated_at,updated_at)
 values
 (p_item_id,p_size_id,v_ingredient_cost,coalesce(p_packaging_cost,0),coalesce(p_labor_cost,0),coalesce(p_overhead_cost,0),v_waste_cost,v_total,coalesce(p_sale_price,0),v_profit,v_margin,nullif(p_target_margin_percent,0),v_min_price,v_suggested_price,now(),now())
 on conflict do nothing returning * into v_cost;

 if v_cost.id is null then
   select * into v_cost from public.product_costs
   where item_id=p_item_id and size_id is not distinct from p_size_id
   order by id desc limit 1;
   update public.product_costs set
    ingredient_cost=v_ingredient_cost,packaging_cost=coalesce(p_packaging_cost,0),
    labor_cost=coalesce(p_labor_cost,0),overhead_cost=coalesce(p_overhead_cost,0),
    waste_cost=v_waste_cost,total_cost=v_total,sale_price=coalesce(p_sale_price,0),
    gross_profit=v_profit,margin_percent=v_margin,target_margin_percent=nullif(p_target_margin_percent,0),
    minimum_price=v_min_price,suggested_price=v_suggested_price,calculated_at=now(),updated_at=now()
   where id=v_cost.id returning * into v_cost;
 end if;
 return v_cost;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.record_inventory_movement(p_ingredient_id bigint, p_movement_type text, p_quantity numeric, p_unit_cost numeric DEFAULT NULL::numeric, p_production_batch_id bigint DEFAULT NULL::bigint, p_notes text DEFAULT NULL::text)
 RETURNS inventory_movements
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
 v_movement public.inventory_movements;
 v_current numeric;
begin
 if p_quantity <= 0 then
   raise exception 'La cantidad debe ser mayor que 0';
 end if;
 if p_movement_type not in ('purchase','use','adjustment','waste','return') then
   raise exception 'Tipo de movimiento inválido';
 end if;

 select current_quantity into v_current
 from public.ingredients
 where id=p_ingredient_id
 for update;

 if not found then
   raise exception 'Ingrediente no encontrado';
 end if;

 if p_movement_type in ('purchase','return') then
   update public.ingredients
   set current_quantity=current_quantity+p_quantity,
       cost_per_unit=coalesce(p_unit_cost,cost_per_unit),
       updated_at=now()
   where id=p_ingredient_id;
 elsif p_movement_type in ('use','waste') then
   if v_current < p_quantity then
     raise exception 'Inventario insuficiente';
   end if;
   update public.ingredients
   set current_quantity=current_quantity-p_quantity,
       updated_at=now()
   where id=p_ingredient_id;
 else
   raise exception 'Los ajustes deben usar una cantidad positiva y se registran como ajuste directo desde administración';
 end if;

 insert into public.inventory_movements
   (ingredient_id,movement_type,quantity,unit_cost,production_batch_id,reference_type,notes)
 values
   (p_ingredient_id,p_movement_type,p_quantity,p_unit_cost,p_production_batch_id,
    case when p_production_batch_id is not null then 'production' else p_movement_type end,
    p_notes)
 returning * into v_movement;

 return v_movement;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.complete_production_batch(p_batch_id bigint)
 RETURNS production_batches
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
 b public.production_batches;
 r public.recipes;
 ri record;
 v_qty numeric;
 v_cost numeric := 0;
 v_already_used boolean;
begin
 select * into b from public.production_batches where id=p_batch_id for update;
 if not found then raise exception 'Lote de producción no encontrado'; end if;
 if b.status='cancelled' then raise exception 'El lote está cancelado'; end if;
 if b.status='completed' then return b; end if;
 if b.recipe_id is null then raise exception 'El lote no tiene receta asociada'; end if;

 select * into r from public.recipes where id=b.recipe_id and active=true;
 if not found then raise exception 'La receta no existe o no está activa'; end if;

 if b.quantity_produced <= 0 then raise exception 'La cantidad producida debe ser mayor que 0'; end if;

 for ri in
   select recipe_ingredients.ingredient_id,
          recipe_ingredients.quantity,
          recipe_ingredients.unit,
          ingredients.cost_per_unit,
          ingredients.current_quantity,
          ingredients.name
   from public.recipe_ingredients
   join public.ingredients on ingredients.id=recipe_ingredients.ingredient_id
   where recipe_ingredients.recipe_id=b.recipe_id
   order by recipe_ingredients.id
   for update of ingredients
 loop
   v_qty := (ri.quantity / r.yield_quantity) * b.quantity_produced;
   if ri.current_quantity < v_qty then
     raise exception 'Inventario insuficiente para %: necesita %, disponible %',
       ri.name, v_qty, ri.current_quantity;
   end if;
   v_cost := v_cost + (v_qty * ri.cost_per_unit);
 end loop;

 select exists(
   select 1 from public.inventory_movements
   where production_batch_id=b.id and movement_type='use'
 ) into v_already_used;

 if v_already_used then
   raise exception 'Este lote ya tiene consumo de inventario registrado';
 end if;

 for ri in
   select recipe_ingredients.ingredient_id,
          recipe_ingredients.quantity,
          recipe_ingredients.unit,
          ingredients.cost_per_unit
   from public.recipe_ingredients
   join public.ingredients on ingredients.id=recipe_ingredients.ingredient_id
   where recipe_ingredients.recipe_id=b.recipe_id
   order by recipe_ingredients.id
 loop
   v_qty := (ri.quantity / r.yield_quantity) * b.quantity_produced;
   update public.ingredients
   set current_quantity=current_quantity-v_qty,
       updated_at=now()
   where id=ri.ingredient_id;

   insert into public.inventory_movements
     (ingredient_id,movement_type,quantity,unit_cost,production_batch_id,reference_type,reference_id,notes)
   values
     (ri.ingredient_id,'use',v_qty,ri.cost_per_unit,b.id,'production',b.id,
      'Consumo automático por producción del lote #'||b.id);
 end loop;

 update public.production_batches
 set total_cost=v_cost,
     cost_per_unit=case when quantity_produced>0 then v_cost/quantity_produced else 0 end,
     status='completed',
     produced_at=coalesce(produced_at,now())
 where id=b.id
 returning * into b;

 return b;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.calculate_payroll_entry(p_hours numeric, p_hourly_rate numeric)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
 select round(greatest(coalesce(p_hours,0),0)*greatest(coalesce(p_hourly_rate,0),0),2)
$function$

\nCREATE OR REPLACE FUNCTION public.record_payroll_entry(p_employee_name text, p_work_date date, p_hours numeric, p_hourly_rate numeric, p_notes text DEFAULT NULL::text)
 RETURNS payroll_entries
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare v public.payroll_entries;
begin
 if coalesce(btrim(p_employee_name),'')='' then raise exception 'Nombre del empleado requerido'; end if;
 if p_hours<=0 or p_hourly_rate<0 then raise exception 'Horas o tarifa inválidas'; end if;
 insert into public.payroll_entries(employee_name,work_date,hours,hourly_rate,gross_pay,notes)
 values(btrim(p_employee_name),p_work_date,p_hours,p_hourly_rate,public.calculate_payroll_entry(p_hours,p_hourly_rate),p_notes)
 returning * into v; return v;
end; $function$

\nCREATE OR REPLACE FUNCTION public.open_cash_register(p_opening_amount numeric)
 RETURNS cash_registers
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_register public.cash_registers;
  v_date date := (now() at time zone 'America/Puerto_Rico')::date;
begin
  if not private.is_menu_admin() then
    raise exception 'No autorizado';
  end if;

  if p_opening_amount not in (15,20) then
    raise exception 'La caja debe abrirse con $15 o $20';
  end if;

  select * into v_register
  from public.cash_registers
  where register_date=v_date
    and status='open'
  for update;

  if found then
    raise exception 'Ya existe una caja abierta para hoy (caja #%)', v_register.id;
  end if;

  insert into public.cash_registers(
    register_date, opened_at, opening_amount, expected_cash,
    status, opened_by
  )
  values(
    v_date, now(), p_opening_amount, p_opening_amount,
    'open', auth.uid()
  )
  returning * into v_register;

  return v_register;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.record_cash_movement(p_register_id bigint, p_movement_type text, p_amount numeric, p_reference_order_id bigint DEFAULT NULL::bigint, p_reason text DEFAULT NULL::text)
 RETURNS cash_movements
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_movement public.cash_movements;
  v_status text;
begin
  if not private.is_menu_admin() then
    raise exception 'No autorizado';
  end if;

  if p_amount <= 0 then
    raise exception 'El monto debe ser mayor que 0';
  end if;

  if p_movement_type not in ('cash_in','cash_out','refund','adjustment','sale') then
    raise exception 'Tipo de movimiento de caja inválido';
  end if;

  select status into v_status
  from public.cash_registers
  where id=p_register_id
  for update;

  if not found then
    raise exception 'Caja no encontrada';
  end if;

  if v_status <> 'open' then
    raise exception 'La caja no está abierta';
  end if;

  if p_movement_type='sale' and p_reference_order_id is not null
     and exists (
       select 1 from public.cash_movements
       where register_id=p_register_id
         and movement_type='sale'
         and reference_order_id=p_reference_order_id
     ) then
    select * into v_movement
    from public.cash_movements
    where register_id=p_register_id
      and movement_type='sale'
      and reference_order_id=p_reference_order_id
    order by id desc limit 1;
    return v_movement;
  end if;

  insert into public.cash_movements(
    register_id,movement_type,amount,reference_order_id,reason,created_by
  )
  values(
    p_register_id,p_movement_type,p_amount,p_reference_order_id,p_reason,auth.uid()
  )
  returning * into v_movement;

  update public.cash_registers
  set expected_cash =
      opening_amount
      + coalesce((
          select sum(case
            when cm.movement_type in ('sale','cash_in') then cm.amount
            when cm.movement_type in ('refund','cash_out') then -cm.amount
            when cm.movement_type='adjustment' then cm.amount
            else 0
          end)
          from public.cash_movements cm
          where cm.register_id=p_register_id
        ),0)
  where id=p_register_id;

  return v_movement;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.close_cash_register(p_register_id bigint, p_counted_cash numeric)
 RETURNS cash_registers
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_register public.cash_registers;
begin
  if not private.is_menu_admin() then
    raise exception 'No autorizado';
  end if;

  if p_counted_cash < 0 then
    raise exception 'El efectivo contado no puede ser negativo';
  end if;

  select * into v_register
  from public.cash_registers
  where id=p_register_id
  for update;

  if not found then
    raise exception 'Caja no encontrada';
  end if;

  if v_register.status <> 'open' then
    raise exception 'La caja ya está cerrada';
  end if;

  update public.cash_registers
  set expected_cash =
      opening_amount
      + coalesce((
          select sum(case
            when cm.movement_type in ('sale','cash_in') then cm.amount
            when cm.movement_type in ('refund','cash_out','cash_drop') then -cm.amount
            when cm.movement_type='adjustment' then cm.amount
            else 0
          end)
          from public.cash_movements cm
          where cm.register_id=p_register_id
        ),0),
      counted_cash=p_counted_cash,
      difference=p_counted_cash - (
        opening_amount
        + coalesce((
            select sum(case
              when cm.movement_type in ('sale','cash_in') then cm.amount
              when cm.movement_type in ('refund','cash_out','cash_drop') then -cm.amount
              when cm.movement_type='adjustment' then cm.amount
              else 0
            end)
            from public.cash_movements cm
            where cm.register_id=p_register_id
          ),0)
      ),
      status='closed',
      closed_at=now(),
      closed_by=auth.uid()
  where id=p_register_id
  returning * into v_register;

  return v_register;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.receive_purchase(p_purchase_id bigint)
 RETURNS purchase_orders
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ declare v_purchase public.purchase_orders; v_item record; begin if not private.is_menu_admin() then raise exception 'No autorizado'; end if; select * into v_purchase from public.purchase_orders where id=p_purchase_id for update; if not found then raise exception 'Orden de compra no encontrada'; end if; if v_purchase.status='received' then return v_purchase; end if; if v_purchase.status<>'ordered' then raise exception 'La orden de compra debe estar en estado ordered para recibirse'; end if; for v_item in select * from public.purchase_items where purchase_id=p_purchase_id order by id loop if v_item.ingredient_id is not null and v_item.quantity>0 then perform public.record_inventory_movement(v_item.ingredient_id,'purchase',v_item.quantity,v_item.unit_cost,null,'Entrada automática por orden de compra #'||p_purchase_id,p_purchase_id); end if; end loop; update public.purchase_orders set status='received',received_date=current_date,updated_at=now() where id=p_purchase_id returning * into v_purchase; return v_purchase; end; $function$

\nCREATE OR REPLACE FUNCTION public.finalize_order(p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_order public.orders;
  v_receipt public.receipts;
  v_register public.cash_registers;
  v_cash_movement public.cash_movements;
  v_loyalty jsonb;
begin
  if not private.is_menu_admin() then
    raise exception 'No autorizado';
  end if;

  select * into v_order
  from public.orders
  where id=p_order_id
  for update;

  if not found then
    raise exception 'Orden % no encontrada', p_order_id;
  end if;

  if v_order.status in ('cancelled','refunded') then
    raise exception 'La orden no puede finalizarse desde estado %', v_order.status;
  end if;

  v_order := public.calculate_order_totals(
    p_order_id,
    v_order.discount_type,
    v_order.discount_value,
    true,
    true
  );

  if v_order.status <> 'completed' then
    update public.orders
    set status='completed',updated_at=now()
    where id=p_order_id
    returning * into v_order;
  end if;

  if v_order.payment_method='cash' then
    select * into v_register
    from public.cash_registers
    where status='open'
      and register_date=(now() at time zone 'America/Puerto_Rico')::date
    order by id desc
    limit 1
    for update;

    if not found then
      raise exception 'No hay una caja abierta para registrar esta venta en efectivo';
    end if;

    select * into v_cash_movement
    from public.cash_movements
    where reference_order_id=p_order_id
      and movement_type='sale'
    order by id desc
    limit 1;

    if not found then
      v_cash_movement := public.record_cash_movement(
        v_register.id,'sale',v_order.total,p_order_id,'Venta #'||p_order_id
      );
    end if;
  end if;

  v_receipt := public.create_sale_receipt(p_order_id);

  select jsonb_build_object(
    'success',true,
    'processed',true,
    'order_id',st.order_id,
    'customer_id',st.customer_id,
    'purchase_amount',st.amount,
    'stamp_earned',st.stamps_earned
  )
  into v_loyalty
  from public.stamp_transactions st
  where st.order_id=p_order_id
  order by st."Created_at" desc
  limit 1;

  if v_loyalty is null then
    v_loyalty := jsonb_build_object(
      'success',true,'processed',false,'reason','no_loyalty_transaction'
    );
  end if;

  return jsonb_build_object(
    'success',true,
    'order_id',v_order.id,
    'status',v_order.status,
    'subtotal',v_order.subtotal,
    'discount',v_order.discount,
    'tax',v_order.tax,
    'total',v_order.total,
    'payment_method',v_order.payment_method,
    'sales_channel',v_order.sales_channel,
    'receipt_id',v_receipt.id,
    'cash_register_id',case when v_cash_movement.id is not null then v_cash_movement.register_id else null end,
    'cash_movement_id',case when v_cash_movement.id is not null then v_cash_movement.id else null end,
    'loyalty',v_loyalty
  );
end;
$function$

\nCREATE OR REPLACE FUNCTION public.record_cash_movement(p_register_id bigint, p_movement_type text, p_amount numeric, p_reference_order_id bigint DEFAULT NULL::bigint, p_reason text DEFAULT NULL::text, p_reference_purchase_id bigint DEFAULT NULL::bigint, p_parent_movement_id bigint DEFAULT NULL::bigint)
 RETURNS cash_movements
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_movement public.cash_movements;
  v_status text;
  v_purchase_status text;
begin
  if not private.is_menu_admin() then
    raise exception 'No autorizado';
  end if;

  if p_amount <= 0 then
    raise exception 'El monto debe ser mayor que 0';
  end if;

  if p_movement_type not in ('cash_in','cash_out','refund','cash_drop','adjustment','sale') then
    raise exception 'Tipo de movimiento de caja inválido';
  end if;

  if p_movement_type in ('cash_out','cash_in') and p_reference_purchase_id is not null then
    select status into v_purchase_status
    from public.purchase_orders
    where id = p_reference_purchase_id;

    if not found then
      raise exception 'La compra relacionada no existe';
    end if;
  end if;

  if p_parent_movement_id is not null then
    if not exists (
      select 1
      from public.cash_movements
      where id = p_parent_movement_id
        and register_id = p_register_id
    ) then
      raise exception 'El movimiento padre no existe en esta caja';
    end if;
  end if;

  select status into v_status
  from public.cash_registers
  where id=p_register_id
  for update;

  if not found then
    raise exception 'Caja no encontrada';
  end if;

  if v_status <> 'open' then
    raise exception 'La caja no está abierta';
  end if;

  if p_movement_type='sale' and p_reference_order_id is not null
     and exists (
       select 1 from public.cash_movements
       where register_id=p_register_id
         and movement_type='sale'
         and reference_order_id=p_reference_order_id
     ) then
    select * into v_movement
    from public.cash_movements
    where register_id=p_register_id
      and movement_type='sale'
      and reference_order_id=p_reference_order_id
    order by id desc limit 1;
    return v_movement;
  end if;

  insert into public.cash_movements(
    register_id,movement_type,amount,reference_order_id,
    reference_purchase_id,parent_movement_id,reason,created_by
  )
  values(
    p_register_id,p_movement_type,p_amount,p_reference_order_id,
    p_reference_purchase_id,p_parent_movement_id,p_reason,auth.uid()
  )
  returning * into v_movement;

  update public.cash_registers
  set expected_cash =
      opening_amount
      + coalesce((
          select sum(case
            when cm.movement_type in ('sale','cash_in') then cm.amount
            when cm.movement_type in ('refund','cash_out','cash_drop') then -cm.amount
            when cm.movement_type='adjustment' then cm.amount
            else 0
          end)
          from public.cash_movements cm
          where cm.register_id=p_register_id
        ),0)
  where id=p_register_id;

  return v_movement;
end;
$function$

\nCREATE OR REPLACE FUNCTION public.pay_purchase_from_cash(p_purchase_id bigint, p_register_id bigint, p_cash_given numeric)
 RETURNS purchase_orders
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ declare v_purchase public.purchase_orders; v_movement public.cash_movements; v_status text; v_change numeric; begin if not private.is_menu_admin() then raise exception 'No autorizado'; end if; if p_cash_given <= 0 then raise exception 'El efectivo entregado debe ser mayor que 0'; end if; select * into v_purchase from public.purchase_orders where id=p_purchase_id for update; if not found then raise exception 'Orden de compra no encontrada'; end if; if v_purchase.status='cancelled' then raise exception 'No se puede pagar una compra cancelada'; end if; if v_purchase.cash_movement_id is not null then raise exception 'Esta compra ya tiene un pago desde Caja'; end if; if coalesce(v_purchase.total,0) <= 0 then raise exception 'La compra debe tener un total mayor que $0 antes de pagarla'; end if; if p_cash_given < v_purchase.total then raise exception 'El efectivo entregado es menor que el total de la compra'; end if; v_change=round(p_cash_given-v_purchase.total,2); select status into v_status from public.cash_registers where id=p_register_id for update; if not found then raise exception 'Caja no encontrada'; end if; if v_status<>'open' then raise exception 'La caja no está abierta'; end if; insert into public.cash_movements(register_id,movement_type,amount,reference_purchase_id,reason,created_by) values(p_register_id,'cash_out',p_cash_given,p_purchase_id,'Pago de compra #'||p_purchase_id,auth.uid()) returning * into v_movement; update public.purchase_orders set payment_method='cash',amount_paid=v_purchase.total,cash_register_id=p_register_id,cash_movement_id=v_movement.id,change_returned=v_change,updated_at=now() where id=p_purchase_id returning * into v_purchase; update public.cash_registers set expected_cash=opening_amount+coalesce((select sum(case when cm.movement_type in ('sale','cash_in') then cm.amount when cm.movement_type in ('refund','cash_out','cash_drop') then -cm.amount when cm.movement_type='adjustment' then cm.amount else 0 end) from public.cash_movements cm where cm.register_id=p_register_id),0) where id=p_register_id; return v_purchase; end; $function$

\nCREATE OR REPLACE FUNCTION public.record_purchase_cash_return(p_purchase_id bigint, p_amount numeric)
 RETURNS cash_movements
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ declare v_purchase public.purchase_orders; v_movement public.cash_movements; v_status text; begin if not private.is_menu_admin() then raise exception 'No autorizado'; end if; if p_amount<=0 then raise exception 'El sobrante debe ser mayor que 0'; end if; select * into v_purchase from public.purchase_orders where id=p_purchase_id for update; if not found then raise exception 'Orden de compra no encontrada'; end if; if v_purchase.cash_movement_id is null or v_purchase.cash_register_id is null then raise exception 'Esta compra no tiene un pago desde Caja'; end if; if p_amount>v_purchase.change_returned then raise exception 'El sobrante registrado supera el sobrante disponible'; end if; if exists(select 1 from public.cash_movements where parent_movement_id=v_purchase.cash_movement_id and movement_type='cash_in') then raise exception 'El sobrante ya fue devuelto a Caja'; end if; select status into v_status from public.cash_registers where id=v_purchase.cash_register_id for update; if v_status<>'open' then raise exception 'La caja de la compra no está abierta'; end if; insert into public.cash_movements(register_id,movement_type,amount,reference_purchase_id,parent_movement_id,reason,created_by) values(v_purchase.cash_register_id,'cash_in',p_amount,p_purchase_id,v_purchase.cash_movement_id,'Devolución de sobrante de compra #'||p_purchase_id,auth.uid()) returning * into v_movement; update public.cash_registers set expected_cash=opening_amount+coalesce((select sum(case when cm.movement_type in ('sale','cash_in') then cm.amount when cm.movement_type in ('refund','cash_out','cash_drop') then -cm.amount when cm.movement_type='adjustment' then cm.amount else 0 end) from public.cash_movements cm where cm.register_id=v_purchase.cash_register_id),0) where id=v_purchase.cash_register_id; return v_movement; end; $function$

\nCREATE OR REPLACE FUNCTION public.record_inventory_movement(p_ingredient_id bigint, p_movement_type text, p_quantity numeric, p_unit_cost numeric DEFAULT NULL::numeric, p_production_batch_id bigint DEFAULT NULL::bigint, p_notes text DEFAULT NULL::text, p_reference_id bigint DEFAULT NULL::bigint)
 RETURNS inventory_movements
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ declare v_movement public.inventory_movements; v_current numeric; begin if p_quantity<=0 then raise exception 'La cantidad debe ser mayor que 0'; end if; if p_movement_type not in ('purchase','use','adjustment','waste','return') then raise exception 'Tipo de movimiento inválido'; end if; select current_quantity into v_current from public.ingredients where id=p_ingredient_id for update; if not found then raise exception 'Ingrediente no encontrado'; end if; if p_movement_type in ('purchase','return') then update public.ingredients set current_quantity=current_quantity+p_quantity,cost_per_unit=coalesce(p_unit_cost,cost_per_unit),updated_at=now() where id=p_ingredient_id; elsif p_movement_type in ('use','waste') then if v_current<p_quantity then raise exception 'Inventario insuficiente'; end if; update public.ingredients set current_quantity=current_quantity-p_quantity,updated_at=now() where id=p_ingredient_id; else raise exception 'Los ajustes deben registrarse desde administración'; end if; insert into public.inventory_movements(ingredient_id,movement_type,quantity,unit_cost,production_batch_id,reference_type,reference_id,notes) values(p_ingredient_id,p_movement_type,p_quantity,p_unit_cost,p_production_batch_id,case when p_production_batch_id is not null then 'production' else p_movement_type end,p_reference_id,p_notes) returning * into v_movement; return v_movement; end; $function$

