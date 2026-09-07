begin;
-- Shared cache and request budget survive serverless cold starts. No API keys are stored here.
create table public.market_provider_cache (
  key text primary key,
  data jsonb,
  expires_at timestamptz not null default '-infinity',
  lease_id uuid,
  lease_until timestamptz not null default '-infinity'
);
create table public.market_provider_budget (
  provider text primary key,
  day date not null,
  used integer not null default 0,
  next_request_at timestamptz not null default '-infinity'
);
alter table public.market_provider_cache enable row level security;
alter table public.market_provider_budget enable row level security;
revoke all on public.market_provider_cache, public.market_provider_budget from public, anon, authenticated;

create function public.reserve_alpha_request(p_key text, p_limit integer default 25) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.market_provider_cache; b public.market_provider_budget; ticket uuid; t timestamptz:=clock_timestamp();
begin
  if p_key is null or length(p_key)>200 or p_limit is null or p_limit<1 or p_limit>10000 then raise exception 'INVALID_INPUT'; end if;
  insert into public.market_provider_budget(provider,day) values('alpha_vantage',(t at time zone 'UTC')::date) on conflict do nothing;
  select * into b from public.market_provider_budget where provider='alpha_vantage' for update;
  select * into c from public.market_provider_cache where key=p_key;
  if c.expires_at>t then return jsonb_build_object('data',c.data); end if;
  if c.lease_until>t then return jsonb_build_object('waitMs',500); end if;
  if b.day<>(t at time zone 'UTC')::date then
    update public.market_provider_budget set day=(t at time zone 'UTC')::date,used=0 where provider=b.provider;
    b.used:=0;
  end if;
  if b.used>=p_limit then return jsonb_build_object('limited',true); end if;
  if b.next_request_at>t then return jsonb_build_object('waitMs',ceil(extract(epoch from b.next_request_at-t)*1000)); end if;
  ticket:=gen_random_uuid();
  update public.market_provider_budget set used=used+1,next_request_at=t+interval '1250 milliseconds' where provider=b.provider;
  insert into public.market_provider_cache(key,lease_id,lease_until) values(p_key,ticket,t+interval '30 seconds')
    on conflict(key) do update set lease_id=ticket,lease_until=excluded.lease_until;
  -- Opportunistically bound obsolete entries; active leases are retained.
  delete from public.market_provider_cache where expires_at<t-interval '8 days' and lease_until<t;
  return jsonb_build_object('ticket',ticket);
end $$;

create function public.save_alpha_response(p_key text,p_ticket uuid,p_data jsonb,p_ttl integer) returns void
language plpgsql security definer set search_path='' as $$
begin
  if p_ttl is null or p_ttl<1 or p_ttl>604800 then raise exception 'INVALID_INPUT'; end if;
  update public.market_provider_cache set data=p_data,expires_at=clock_timestamp()+make_interval(secs=>p_ttl),lease_until='-infinity'
    where key=p_key and lease_id=p_ticket;
end $$;
revoke all on function public.reserve_alpha_request(text,integer),public.save_alpha_response(text,uuid,jsonb,integer) from public,anon,authenticated;
grant execute on function public.reserve_alpha_request(text,integer),public.save_alpha_response(text,uuid,jsonb,integer) to service_role;
commit;
