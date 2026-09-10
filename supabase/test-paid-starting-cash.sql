-- Run after paid_starting_cash in a disposable database.
begin;
insert into auth.users(id) values ('99999999-1111-4111-8111-111111111111'),('99999999-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub','99999999-1111-4111-8111-111111111111',true);
select public.get_state();
do $$ begin
  if (select cash_cents from public.wallets where user_id=auth.uid())<>0 then raise exception 'New wallet must start empty'; end if;
  if exists(select 1 from public.ledger where user_id=auth.uid() and kind='welcome') then raise exception 'No welcome credit'; end if;
end $$;
reset role;
select public.apply_purchase_event('paid-start-1','99999999-1111-4111-8111-111111111111','paid-tx-1','ei.cash.10000','SANDBOX','app','purchase');
select public.apply_purchase_event('paid-start-2','99999999-1111-4111-8111-111111111111','paid-tx-1','ei.cash.10000','SANDBOX','app','purchase');
-- A webhook arriving before the first state request must not grant extra money.
select public.apply_purchase_event('paid-start-3','99999999-2222-4222-8222-222222222222','paid-tx-2','ei.cash.10000','SANDBOX','app','purchase');
do $$ begin
  if (select count(*) from public.wallets where user_id in ('99999999-1111-4111-8111-111111111111','99999999-2222-4222-8222-222222222222') and cash_cents=1000000 and contributed_cents=1000000)<>2 then raise exception 'Purchase must credit exactly 10000 once'; end if;
end $$;
select public.apply_purchase_event('paid-refund-1','99999999-2222-4222-8222-222222222222','paid-tx-2','ei.cash.10000','SANDBOX','app','refund');
do $$ begin
  if (select cash_cents from public.wallets where user_id='99999999-2222-4222-8222-222222222222')<>0 then raise exception 'Refund must remove the credited cash'; end if;
end $$;
rollback;
