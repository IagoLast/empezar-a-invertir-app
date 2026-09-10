-- Run only in a disposable database, after every migration.
begin;
insert into auth.users(id) values ('77777777-1111-4111-8111-111111111111');
do $$
declare u uuid := '77777777-1111-4111-8111-111111111111'; p record; result jsonb;
begin
  for p in select * from (values ('ei.cash.1000',100000::bigint),('ei.cash.10000',1000000::bigint),('ei.cash.1000000',100000000::bigint)) as packs(id,cents) loop
    result := public.apply_purchase_event('pack-'||p.id,u,'tx-'||p.id,p.id,'SANDBOX','test-store','purchase');
    if (result->>'appliedCents')::bigint <> p.cents then raise exception 'Wrong grant for %',p.id; end if;
    perform public.apply_purchase_event('pack-'||p.id,u,'tx-'||p.id,p.id,'SANDBOX','test-store','purchase');
    result := public.apply_purchase_event('duplicate-'||p.id,u,'tx-'||p.id,p.id,'SANDBOX','test-store','purchase');
    if (result->>'appliedCents')::bigint <> 0 then raise exception 'Duplicate granted cash'; end if;
    result := public.apply_purchase_event('refund-'||p.id,u,'tx-'||p.id,p.id,'SANDBOX','test-store','refund');
    if (result->>'appliedCents')::bigint <> -p.cents then raise exception 'Wrong refund'; end if;
    perform public.apply_purchase_event('late-'||p.id,u,'tx-'||p.id,p.id,'SANDBOX','test-store','purchase');
    if (select cash_cents from public.wallets where user_id=u) <> 0 then raise exception 'Refunded purchase granted cash'; end if;
  end loop;
end $$;
rollback;
