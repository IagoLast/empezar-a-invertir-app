begin;

create or replace function public.quote_cache(p_symbol text) returns jsonb language plpgsql security definer set search_path='' as $$
declare q jsonb; acquired boolean:=false;
begin
  if p_symbol is null or p_symbol !~ '^[A-Z0-9][A-Z0-9.-]{0,19}$' then raise exception 'INVALID_INPUT'; end if;
  select data into q from public.quotes where symbol=p_symbol order by created_at desc limit 1;
  insert into public.refresh_leases values('quote:'||p_symbol,now()+interval '30 seconds')
  on conflict(key) do update set retry_at=excluded.retry_at where public.refresh_leases.retry_at<now() returning true into acquired;
  return jsonb_build_object('quote',q,'refresh',coalesce(acquired,false));
end $$;
create or replace function public.save_quote(p_quote jsonb) returns void language plpgsql security definer set search_path='' as $$
declare asset_kind text;
begin
  -- Keep existing API instances compatible during a rolling deployment.
  asset_kind := coalesce(p_quote->>'kind', (select kind from public.instruments where symbol=p_quote->>'symbol'));
  if p_quote->>'symbol' is null or p_quote->>'symbol' !~ '^[A-Z0-9][A-Z0-9.-]{0,19}$'
    or p_quote->>'currency' is distinct from 'USD'
    or asset_kind is null or asset_kind not in ('stock','etf','bond_etf')
    or (p_quote->>'priceCents')::bigint is null or (p_quote->>'priceCents')::bigint <= 0 then
    raise exception 'INVALID_INPUT';
  end if;
  -- Only service_role can register provider-validated assets or write execution quotes.
  insert into public.instruments(symbol,kind) values(p_quote->>'symbol',asset_kind) on conflict(symbol) do nothing;
  insert into public.quotes(id,symbol,data) values((p_quote->>'id')::uuid,p_quote->>'symbol',p_quote);
end $$;

create or replace function public.get_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.ensure_wallet(); result jsonb;
begin
  -- One SQL snapshot for wallet, positions and ledger.
  select jsonb_build_object(
    'userId',w.user_id,'cashCents',w.cash_cents,'contributedCents',w.contributed_cents,'currency','USD',
    'positions',coalesce((select jsonb_agg(jsonb_build_object('symbol',p.symbol,'units',p.units,'costCents',p.cost_cents)) from public.positions p where p.user_id=u),'[]'::jsonb),
    'quotes',coalesce((select jsonb_agg(q.data) from (select distinct on(symbol) data from public.quotes where symbol in ('AAPL','MSFT','VTI','BND') or symbol in (select p.symbol from public.positions p where p.user_id=u) order by symbol,created_at desc) q),'[]'::jsonb),
    'orders',coalesce((select jsonb_agg(x.item order by x.d desc) from (select o.created_at d,jsonb_build_object('id',o.id,'requestId',o.request_id,'symbol',o.symbol,'side',o.side,'units',o.units,'priceCents',o.price_cents,'feeCents',o.fee_cents,'createdAt',o.created_at) item from public.orders o where o.user_id=u order by o.created_at desc limit 50) x),'[]'::jsonb),
    'completedLessons',coalesce((select jsonb_agg(lesson_id) from public.lesson_progress where user_id=u),'[]'::jsonb),
    'purchases',coalesce((select jsonb_agg(jsonb_build_object('transactionId',transaction_id,'productId',product_id,'credited',credited,'refunded',refunded)) from public.purchase_receipts where user_id=u),'[]'::jsonb)
  ) into result from public.wallets w where w.user_id=u;
  return result;
end $$;

commit;
