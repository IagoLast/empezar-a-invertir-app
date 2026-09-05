begin;
create table public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  cash_cents bigint not null default 1000000,
  contributed_cents bigint not null default 1000000,
  created_at timestamptz not null default now()
);
create table public.instruments (symbol text primary key, kind text not null, active boolean not null default true);
insert into public.instruments values ('AAPL','stock',true),('MSFT','stock',true),('VTI','etf',true),('BND','bond_etf',true);
create table public.positions (
  user_id uuid not null references public.wallets on delete cascade,
  symbol text not null references public.instruments,
  units integer not null check (units > 0),
  cost_cents bigint not null check (cost_cents >= 0),
  primary key(user_id,symbol)
);
create table public.quotes (
  id uuid primary key,
  symbol text not null references public.instruments,
  data jsonb not null,
  created_at timestamptz not null default now()
);
create index quotes_symbol_date on public.quotes(symbol,created_at desc);
create table public.refresh_leases (key text primary key, retry_at timestamptz not null);
create table public.fundamentals (symbol text primary key references public.instruments, data jsonb not null, created_at timestamptz not null default now());
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.wallets on delete cascade,
  request_id uuid not null,
  symbol text not null references public.instruments,
  side text not null check (side in ('buy','sell')),
  units integer not null check (units > 0),
  price_cents bigint not null check (price_cents > 0),
  fee_cents bigint not null check (fee_cents >= 0),
  quote_id uuid not null references public.quotes,
  created_at timestamptz not null default now(),
  unique(user_id,request_id)
);
create table public.lesson_progress (
  user_id uuid not null references public.wallets on delete cascade,
  lesson_id text not null check (lesson_id in ('lesson-1','lesson-2','lesson-3','lesson-4')),
  primary key(user_id,lesson_id)
);
create table public.ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.wallets on delete cascade,
  kind text not null,
  amount_cents bigint not null,
  reference text not null,
  created_at timestamptz not null default now(),
  unique(user_id,kind,reference)
);
create table public.purchase_products (id text primary key, credit_cents bigint not null check (credit_cents > 0));
insert into public.purchase_products values ('ei.cash.10000',1000000),('ei.cash.25000',2500000);
create table public.purchase_receipts (
  app text not null, environment text not null, transaction_id text not null,
  user_id uuid not null references public.wallets on delete cascade,
  product_id text not null references public.purchase_products,
  credited boolean not null default false, refunded boolean not null default false,
  primary key(app,environment,transaction_id)
);
create table public.purchase_events (event_id text primary key, created_at timestamptz not null default now());

-- Clients may read their own state; mutations only through constrained RPCs.
alter table public.wallets enable row level security;
alter table public.positions enable row level security;
alter table public.orders enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.ledger enable row level security;
alter table public.purchase_receipts enable row level security;
alter table public.instruments enable row level security;
alter table public.quotes enable row level security;
alter table public.refresh_leases enable row level security;
alter table public.fundamentals enable row level security;
alter table public.purchase_products enable row level security;
alter table public.purchase_events enable row level security;
create policy own_wallet on public.wallets for select to authenticated using(user_id=auth.uid());
create policy own_positions on public.positions for select to authenticated using(user_id=auth.uid());
create policy own_orders on public.orders for select to authenticated using(user_id=auth.uid());
create policy own_progress on public.lesson_progress for select to authenticated using(user_id=auth.uid());
create policy own_ledger on public.ledger for select to authenticated using(user_id=auth.uid());
create policy own_receipts on public.purchase_receipts for select to authenticated using(user_id=auth.uid());
revoke all on all tables in schema public from anon, authenticated;
grant select on public.wallets,public.positions,public.orders,public.lesson_progress,public.ledger,public.purchase_receipts to authenticated;

create function public.ensure_wallet() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
  if u is null then raise exception 'UNAUTHORIZED'; end if;
  insert into public.wallets(user_id) values(u) on conflict do nothing;
  insert into public.ledger(user_id,kind,amount_cents,reference) values(u,'welcome',1000000,'initial') on conflict do nothing;
  return u;
end $$;

create function public.get_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.ensure_wallet(); result jsonb;
begin
  -- One SQL snapshot for wallet, positions and ledger.
  select jsonb_build_object(
    'userId',w.user_id,'cashCents',w.cash_cents,'contributedCents',w.contributed_cents,'currency','USD',
    'positions',coalesce((select jsonb_agg(jsonb_build_object('symbol',p.symbol,'units',p.units,'costCents',p.cost_cents)) from public.positions p where p.user_id=u),'[]'::jsonb),
    'quotes',coalesce((select jsonb_agg(q.data) from (select distinct on(symbol) data from public.quotes order by symbol,created_at desc) q),'[]'::jsonb),
    'orders',coalesce((select jsonb_agg(x.item order by x.d desc) from (select o.created_at d,jsonb_build_object('id',o.id,'requestId',o.request_id,'symbol',o.symbol,'side',o.side,'units',o.units,'priceCents',o.price_cents,'feeCents',o.fee_cents,'createdAt',o.created_at) item from public.orders o where o.user_id=u order by o.created_at desc limit 50) x),'[]'::jsonb),
    'completedLessons',coalesce((select jsonb_agg(lesson_id) from public.lesson_progress where user_id=u),'[]'::jsonb),
    'purchases',coalesce((select jsonb_agg(jsonb_build_object('transactionId',transaction_id,'productId',product_id,'credited',credited,'refunded',refunded)) from public.purchase_receipts where user_id=u),'[]'::jsonb)
  ) into result from public.wallets w where w.user_id=u;
  return result;
end $$;

create function public.place_trade(p_request uuid,p_symbol text,p_side text,p_units integer,p_quote uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.ensure_wallet(); w public.wallets; old public.orders; q public.quotes; p public.positions;
  price bigint; total bigint; fee bigint:=100; new_cost bigint;
begin
  if p_request is null or p_quote is null or p_side is null or p_side not in ('buy','sell') or p_units is null or p_units<1 or p_units>100000 then raise exception 'INVALID_INPUT'; end if;
  select * into w from public.wallets where user_id=u for update;
  select * into old from public.orders where user_id=u and request_id=p_request;
  if found then
    if old.symbol<>p_symbol or old.side<>p_side or old.units<>p_units or old.quote_id<>p_quote then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return public.get_state();
  end if;
  if not exists(select 1 from public.instruments where symbol=p_symbol and active) then raise exception 'INVALID_INPUT'; end if;
  select * into q from public.quotes where id=p_quote and symbol=p_symbol;
  if not found then raise exception 'QUOTE_UNAVAILABLE'; end if;
  if (q.data->>'expiresAt')::timestamptz<clock_timestamp() then raise exception 'STALE_QUOTE'; end if;
  if not (q.data->>'marketOpen')::boolean then raise exception 'MARKET_CLOSED'; end if;
  if not (q.data->>'tradable')::boolean then raise exception 'QUOTE_UNAVAILABLE'; end if;
  price:=(q.data->>'priceCents')::bigint; total:=price*p_units;
  select * into p from public.positions where user_id=u and symbol=p_symbol;
  if p_side='buy' then
    if w.cash_cents<total+fee then raise exception 'INSUFFICIENT_CASH'; end if;
    update public.wallets set cash_cents=cash_cents-total-fee where user_id=u;
    insert into public.positions(user_id,symbol,units,cost_cents) values(u,p_symbol,p_units,total+fee)
      on conflict(user_id,symbol) do update set units=public.positions.units+excluded.units,cost_cents=public.positions.cost_cents+excluded.cost_cents;
  else
    if p.units is null or p.units<p_units then raise exception 'INSUFFICIENT_UNITS'; end if;
    if total<fee then raise exception 'INVALID_INPUT'; end if;
    update public.wallets set cash_cents=cash_cents+total-fee where user_id=u;
    if p.units=p_units then delete from public.positions where user_id=u and symbol=p_symbol;
    else
      new_cost:=round(p.cost_cents::numeric*(p.units-p_units)/p.units);
      update public.positions set units=units-p_units,cost_cents=new_cost where user_id=u and symbol=p_symbol;
    end if;
  end if;
  insert into public.orders(user_id,request_id,symbol,side,units,price_cents,fee_cents,quote_id) values(u,p_request,p_symbol,p_side,p_units,price,fee,p_quote);
  insert into public.ledger(user_id,kind,amount_cents,reference) values(u,'trade',case when p_side='buy' then -total-fee else total-fee end,p_request::text);
  return public.get_state();
end $$;

create function public.complete_lesson(p_lesson text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.ensure_wallet();
begin
  if p_lesson is null or p_lesson not in ('lesson-1','lesson-2','lesson-3','lesson-4') then raise exception 'INVALID_INPUT'; end if;
  insert into public.lesson_progress values(u,p_lesson) on conflict do nothing;
  return public.get_state();
end $$;

-- Shared refresh lease limits the feed to one refresh/symbol/30 seconds, even across lambdas.
create function public.quote_cache(p_symbol text) returns jsonb language plpgsql security definer set search_path='' as $$
declare q jsonb; acquired boolean:=false;
begin
  if not exists(select 1 from public.instruments where symbol=p_symbol and active) then raise exception 'INVALID_INPUT'; end if;
  select data into q from public.quotes where symbol=p_symbol order by created_at desc limit 1;
  insert into public.refresh_leases values('quote:'||p_symbol,now()+interval '30 seconds')
  on conflict(key) do update set retry_at=excluded.retry_at where public.refresh_leases.retry_at<now() returning true into acquired;
  return jsonb_build_object('quote',q,'refresh',coalesce(acquired,false));
end $$;
create function public.save_quote(p_quote jsonb) returns void language sql security definer set search_path='' as $$
  insert into public.quotes(id,symbol,data) values((p_quote->>'id')::uuid,p_quote->>'symbol',p_quote);
$$;
create function public.fundamentals_cache(p_symbol text) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb; acquired boolean:=false;
begin
  select data into d from public.fundamentals where symbol=p_symbol and created_at>now()-interval '24 hours';
  if d is not null then return jsonb_build_object('data',d,'refresh',false); end if;
  insert into public.refresh_leases values('fundamentals:'||p_symbol,now()+interval '5 minutes')
    on conflict(key) do update set retry_at=excluded.retry_at where public.refresh_leases.retry_at<now() returning true into acquired;
  return jsonb_build_object('data',d,'refresh',coalesce(acquired,false));
end $$;
create function public.save_fundamentals(p_symbol text,p_data jsonb) returns void language sql security definer set search_path='' as $$
  insert into public.fundamentals values(p_symbol,p_data,now()) on conflict(symbol) do update set data=excluded.data,created_at=excluded.created_at;
$$;

-- Atomic and idempotent at BOTH event and store transaction level. Refund-before-purchase is supported.
create function public.apply_purchase_event(p_event text,p_user uuid,p_transaction text,p_product text,p_environment text,p_app text,p_kind text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare receipt public.purchase_receipts; amount bigint; delta bigint:=0;
begin
  if p_kind is null or p_kind not in ('purchase','refund') or p_environment is null or p_environment not in ('SANDBOX','PRODUCTION') then raise exception 'INVALID_INPUT'; end if;
  select credit_cents into amount from public.purchase_products where id=p_product;
  if amount is null then raise exception 'INVALID_INPUT'; end if;
  -- Deleted accounts cannot be resurrected by a late webhook.
  if not exists(select 1 from auth.users where id=p_user) then return jsonb_build_object('ignored',true); end if;
  insert into public.wallets(user_id) values(p_user) on conflict do nothing;
  perform 1 from public.wallets where user_id=p_user for update;
  insert into public.ledger(user_id,kind,amount_cents,reference) values(p_user,'welcome',1000000,'initial') on conflict do nothing;
  insert into public.purchase_events values(p_event,now()) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate',true); end if;
  insert into public.purchase_receipts(app,environment,transaction_id,user_id,product_id) values(p_app,p_environment,p_transaction,p_user,p_product) on conflict do nothing;
  select * into receipt from public.purchase_receipts where app=p_app and environment=p_environment and transaction_id=p_transaction for update;
  if receipt.user_id<>p_user or receipt.product_id<>p_product then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
  if p_kind='purchase' and not receipt.credited and not receipt.refunded then
    delta:=amount;
    update public.purchase_receipts set credited=true where app=p_app and environment=p_environment and transaction_id=p_transaction;
  elsif p_kind='refund' and not receipt.refunded then
    if receipt.credited then delta:=-amount; end if;
    update public.purchase_receipts set refunded=true where app=p_app and environment=p_environment and transaction_id=p_transaction;
  end if;
  if delta<>0 then
    -- A refund can produce debt. New buys are blocked by the cash check; sell remains possible.
    update public.wallets set cash_cents=cash_cents+delta,contributed_cents=contributed_cents+delta where user_id=p_user;
    insert into public.ledger(user_id,kind,amount_cents,reference) values(p_user,p_kind,delta,p_app||':'||p_environment||':'||p_transaction);
  end if;
  return jsonb_build_object('appliedCents',delta);
end $$;

revoke all on function public.ensure_wallet(),public.get_state(),public.place_trade(uuid,text,text,integer,uuid),public.complete_lesson(text),public.quote_cache(text),public.save_quote(jsonb),public.fundamentals_cache(text),public.save_fundamentals(text,jsonb),public.apply_purchase_event(text,uuid,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.get_state(),public.place_trade(uuid,text,text,integer,uuid),public.complete_lesson(text) to authenticated;
grant execute on function public.quote_cache(text),public.save_quote(jsonb),public.fundamentals_cache(text),public.save_fundamentals(text,jsonb),public.apply_purchase_event(text,uuid,text,text,text,text,text) to service_role;
commit;
