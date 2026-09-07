begin;
create table public.simulated_orders (
  id uuid primary key, user_id uuid not null references public.wallets on delete cascade,
  symbol text not null references public.instruments, side text not null check(side in ('buy','sell')),
  units integer not null check(units between 1 and 100000), quote_id uuid not null references public.quotes,
  price_cents bigint not null check(price_cents > 0), limit_cents bigint check(limit_cents > 0),
  average_daily_volume bigint, status text not null default 'pending' check(status in ('pending','executed','cancelled')),
  revision integer not null default 1, created_at timestamptz not null default clock_timestamp(),
  execute_at timestamptz not null, completed_at timestamptz
);
create index simulated_orders_due on public.simulated_orders(execute_at) where status='pending';
alter table public.simulated_orders enable row level security;
revoke all on public.simulated_orders from public,anon,authenticated;
grant select on public.simulated_orders to authenticated;
create policy own_simulated_orders on public.simulated_orders for select to authenticated using(user_id=(select auth.uid()));

-- Preserve the read-only state function and add reservations and queued orders.
alter function public.get_state() rename to get_state_before_simulation;
revoke all on function public.get_state_before_simulation() from public,anon,authenticated;
create function public.get_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.ensure_wallet(); result jsonb;
begin
  perform 1 from public.wallets where user_id=u for share;
  result:=public.get_state_before_simulation();
  return result || jsonb_build_object(
    'reservedCashCents',coalesce((select sum(price_cents*units+100) from public.simulated_orders where user_id=u and side='buy' and status='pending'),0),
    'simulatedOrders',coalesce((select jsonb_agg(jsonb_build_object('id',id,'symbol',symbol,'side',side,'units',units,
      'priceCents',price_cents,'limitCents',limit_cents,'status',status,'revision',revision,'createdAt',created_at,
      'executeAt',execute_at,'averageDailyVolume',average_daily_volume) order by created_at desc)
      from (select * from public.simulated_orders where user_id=u order by created_at desc limit 100) s),'[]'::jsonb));
end $$;

create function public.submit_simulated_order(p_request uuid,p_symbol text,p_side text,p_units integer,p_quote uuid,p_limit bigint default null,p_revision integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.ensure_wallet(); w public.wallets; old public.simulated_orders; q public.quotes;
  price bigint; volume bigint; seconds integer; available bigint;
begin
  if p_request is null or p_quote is null or p_side is null or p_side not in ('buy','sell') or p_units is null or p_units not between 1 and 100000
    or (p_limit is not null and (p_limit<=0 or p_limit>1000000000)) then raise exception 'INVALID_INPUT'; end if;
  select * into w from public.wallets where user_id=u for update;
  if exists(select 1 from public.orders where user_id=u and request_id=p_request) and not exists(select 1 from public.simulated_orders where id=p_request and user_id=u) then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
  select * into old from public.simulated_orders where id=p_request;
  if found then
    if old.user_id<>u then raise exception 'INVALID_INPUT'; end if;
    -- A lost-response retry is safe even after execution or cancellation.
    if old.symbol=p_symbol and old.side=p_side and old.units=p_units and old.quote_id=p_quote and old.limit_cents is not distinct from p_limit then return public.get_state(); end if;
    if old.status<>'pending' or old.execute_at<=clock_timestamp() then raise exception 'ORDER_FINISHED'; end if;
    if p_revision is null or old.revision<>p_revision then raise exception 'ORDER_CHANGED'; end if;
    if old.symbol<>p_symbol or old.side<>p_side then raise exception 'INVALID_INPUT'; end if;
  elsif p_revision is not null then raise exception 'ORDER_CHANGED'; end if;
  if not exists(select 1 from public.instruments where symbol=p_symbol and active) then raise exception 'INVALID_INPUT'; end if;
  select * into q from public.quotes where id=p_quote and symbol=p_symbol;
  if not found then raise exception 'QUOTE_UNAVAILABLE'; end if;
  if q.data->>'source' is distinct from 'Finnhub' or q.data->>'asOf' is null or q.data->>'expiresAt' is null or (q.data->>'asOf')::timestamptz < clock_timestamp()-interval '7 days'
    or (q.data->>'asOf')::timestamptz > clock_timestamp()+interval '1 minute'
    or (q.data->>'expiresAt')::timestamptz <= clock_timestamp() then raise exception 'STALE_QUOTE'; end if;
  price:=(q.data->>'priceCents')::bigint;
  if price is null or price<=0 then raise exception 'QUOTE_UNAVAILABLE'; end if;
  -- Explicit educational simulation: a chosen limit is the simulated fill price,
  -- not a claim that the real market traded at that price.
  if p_limit is not null then price:=case when p_side='buy' then least(price,p_limit) else greatest(price,p_limit) end; end if;
  if p_side='buy' then
    select w.cash_cents-coalesce(sum(price_cents*units+100),0) into available from public.simulated_orders where user_id=u and side='buy' and status='pending' and id<>p_request;
    if available<price*p_units+100 then raise exception 'INSUFFICIENT_CASH'; end if;
  else
    select coalesce((select units from public.positions where user_id=u and symbol=p_symbol),0)-coalesce(sum(units),0) into available
      from public.simulated_orders where user_id=u and symbol=p_symbol and side='sell' and status='pending' and id<>p_request;
    if available<p_units then raise exception 'INSUFFICIENT_UNITS'; end if;
    if price*p_units<100 then raise exception 'INVALID_INPUT'; end if;
  end if;
  volume:=(q.data->>'averageDailyVolume')::bigint;
  seconds:=case when volume>=10000000 then 8+floor(random()*8)::integer when volume>=1000000 then 15+floor(random()*16)::integer
    when volume>0 then 30+floor(random()*31)::integer else 20+floor(random()*21)::integer end;
  insert into public.simulated_orders(id,user_id,symbol,side,units,quote_id,price_cents,limit_cents,average_daily_volume,execute_at)
    values(p_request,u,p_symbol,p_side,p_units,p_quote,price,p_limit,volume,clock_timestamp()+make_interval(secs=>seconds))
    on conflict(id) do update set units=excluded.units,quote_id=excluded.quote_id,price_cents=excluded.price_cents,
      limit_cents=excluded.limit_cents,revision=public.simulated_orders.revision+1;
  return public.get_state();
end $$;

create function public.cancel_simulated_order(p_request uuid,p_revision integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.ensure_wallet(); old public.simulated_orders;
begin
  perform 1 from public.wallets where user_id=u for update;
  select * into old from public.simulated_orders where id=p_request and user_id=u;
  if not found then raise exception 'INVALID_INPUT'; end if;
  if old.status='cancelled' then return public.get_state(); end if;
  if old.status<>'pending' or old.execute_at<=clock_timestamp() then raise exception 'ORDER_FINISHED'; end if;
  if old.revision is distinct from p_revision then raise exception 'ORDER_CHANGED'; end if;
  update public.simulated_orders set status='cancelled',completed_at=clock_timestamp(),revision=revision+1 where id=p_request;
  return public.get_state();
end $$;

create function public.execute_simulated_orders() returns integer language plpgsql security definer set search_path='' as $$
declare candidate record; o public.simulated_orders; p public.positions; total bigint; count integer:=0;
begin
  for candidate in select id,user_id from public.simulated_orders where status='pending' and execute_at<=clock_timestamp() order by execute_at limit 1000 loop
    -- Same lock order as submission/edit/cancellation prevents double fills and overspending.
    perform 1 from public.wallets where user_id=candidate.user_id for update;
    select * into o from public.simulated_orders where id=candidate.id for update;
    if o.status<>'pending' then continue; end if;
    total:=o.price_cents*o.units;
    select * into p from public.positions where user_id=o.user_id and symbol=o.symbol;
    if o.side='buy' then
      update public.wallets set cash_cents=cash_cents-total-100 where user_id=o.user_id;
      insert into public.positions(user_id,symbol,units,cost_cents) values(o.user_id,o.symbol,o.units,total+100)
        on conflict(user_id,symbol) do update set units=public.positions.units+excluded.units,cost_cents=public.positions.cost_cents+excluded.cost_cents;
    else
      update public.wallets set cash_cents=cash_cents+total-100 where user_id=o.user_id;
      if p.units=o.units then delete from public.positions where user_id=o.user_id and symbol=o.symbol;
      else update public.positions set units=p.units-o.units,cost_cents=round(p.cost_cents::numeric*(p.units-o.units)/p.units) where user_id=o.user_id and symbol=o.symbol; end if;
    end if;
    insert into public.orders(user_id,request_id,symbol,side,units,price_cents,fee_cents,quote_id)
      values(o.user_id,o.id,o.symbol,o.side,o.units,o.price_cents,100,o.quote_id);
    insert into public.ledger(user_id,kind,amount_cents,reference) values(o.user_id,'trade',case when o.side='buy' then -total-100 else total-100 end,o.id::text);
    update public.simulated_orders set status='executed',completed_at=clock_timestamp() where id=o.id;
    count:=count+1;
  end loop;
  return count;
end $$;
-- Existing app builds retain instant trades, but cannot spend reserved funds/units.
alter function public.place_trade(uuid,text,text,integer,uuid) rename to place_trade_before_simulation;
revoke all on function public.place_trade_before_simulation(uuid,text,text,integer,uuid) from public,anon,authenticated;
create function public.place_trade(p_request uuid,p_symbol text,p_side text,p_units integer,p_quote uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.ensure_wallet(); reserved bigint; available bigint; price bigint;
begin
  perform 1 from public.wallets where user_id=u for update;
  if exists(select 1 from public.orders where user_id=u and request_id=p_request) then
    return public.place_trade_before_simulation(p_request,p_symbol,p_side,p_units,p_quote);
  end if;
  if exists(select 1 from public.simulated_orders where id=p_request) then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
  if p_side='buy' then
    select coalesce(sum(price_cents*units+100),0) into reserved from public.simulated_orders where user_id=u and side='buy' and status='pending';
    select cash_cents-reserved into available from public.wallets where user_id=u;
    select (data->>'priceCents')::bigint into price from public.quotes where id=p_quote and symbol=p_symbol;
    if available<price*p_units+100 then raise exception 'INSUFFICIENT_CASH'; end if;
  else
    select coalesce(sum(units),0) into reserved from public.simulated_orders where user_id=u and symbol=p_symbol and side='sell' and status='pending';
    select units-reserved into available from public.positions where user_id=u and symbol=p_symbol;
    if coalesce(available,0)<p_units then raise exception 'INSUFFICIENT_UNITS'; end if;
  end if;
  return public.place_trade_before_simulation(p_request,p_symbol,p_side,p_units,p_quote);
end $$;
revoke all on function public.place_trade(uuid,text,text,integer,uuid) from public,anon;
grant execute on function public.place_trade(uuid,text,text,integer,uuid) to authenticated;
revoke all on function public.get_state(),public.submit_simulated_order(uuid,text,text,integer,uuid,bigint,integer),public.cancel_simulated_order(uuid,integer),public.execute_simulated_orders() from public,anon,authenticated;
grant execute on function public.get_state(),public.submit_simulated_order(uuid,text,text,integer,uuid,bigint,integer),public.cancel_simulated_order(uuid,integer) to authenticated;
grant execute on function public.execute_simulated_orders() to service_role;
commit;
