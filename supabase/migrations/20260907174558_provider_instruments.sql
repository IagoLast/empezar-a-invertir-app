begin;
-- Reapply provider-validated registration for installations still using the initial catalog gate.
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

commit;
