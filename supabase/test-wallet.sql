-- Run only against a disposable database. Errors abort the verification.
insert into auth.users values ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
set role authenticated;
select public.get_state();
reset role;
select public.save_quote(jsonb_build_object('id','33333333-3333-4333-8333-333333333333','symbol','AAPL','priceCents',10000,'currency','USD','marketOpen',true,'tradable',true,'expiresAt',now()+interval '1 hour','asOf',now(),'fetchedAt',now(),'source','test fixture','mode','realtime','delaySeconds',0,'changePercent',0));
set role authenticated;
select public.place_trade('44444444-4444-4444-8444-444444444444','AAPL','buy',2,'33333333-3333-4333-8333-333333333333');
select public.place_trade('44444444-4444-4444-8444-444444444444','AAPL','buy',2,'33333333-3333-4333-8333-333333333333');
do $$ begin
  if (select cash_cents from public.wallets)<>979900 then raise exception 'FAIL: duplicate trade or fee'; end if;
  if (select count(*) from public.orders)<>1 then raise exception 'FAIL: duplicate order'; end if;
  begin perform public.place_trade('55555555-5555-4555-8555-555555555555','AAPL','buy',1000,'33333333-3333-4333-8333-333333333333'); raise exception 'FAIL: overdraft'; exception when others then if sqlerrm<>'INSUFFICIENT_CASH' then raise; end if; end;
  begin perform public.place_trade('55555555-5555-4555-8555-555555555555','AAPL','sell',3,'33333333-3333-4333-8333-333333333333'); raise exception 'FAIL: short sale'; exception when others then if sqlerrm<>'INSUFFICIENT_UNITS' then raise; end if; end;
  begin perform public.place_trade('44444444-4444-4444-8444-444444444444','AAPL','buy',3,'33333333-3333-4333-8333-333333333333'); raise exception 'FAIL: reused key'; exception when others then if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise; end if; end;
  begin update public.wallets set cash_cents=999999; raise exception 'FAIL: direct wallet write'; exception when insufficient_privilege then null; end;
  begin perform public.save_quote('{}'); raise exception 'FAIL: forged quote'; exception when insufficient_privilege then null; end;
  begin perform public.apply_purchase_event('forged','11111111-1111-4111-8111-111111111111','tx','ei.cash.10000','SANDBOX','app','purchase'); raise exception 'FAIL: forged credits'; exception when insufficient_privilege then null; end;
end $$;
select public.place_trade('66666666-6666-4666-8666-666666666666','AAPL','sell',1,'33333333-3333-4333-8333-333333333333');
do $$ begin if (select cost_cents from public.positions)<>10050 then raise exception 'FAIL: cost basis'; end if; end $$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
select public.get_state();
do $$ begin
  if (select count(*) from public.orders)<>0 then raise exception 'FAIL: RLS orders'; end if;
  if (select count(*) from public.wallets)<>1 then raise exception 'FAIL: RLS wallet'; end if;
end $$;
reset role;
select public.apply_purchase_event('e1','11111111-1111-4111-8111-111111111111','tx1','ei.cash.10000','SANDBOX','app','purchase');
select public.apply_purchase_event('e1','11111111-1111-4111-8111-111111111111','tx1','ei.cash.10000','SANDBOX','app','purchase');
select public.apply_purchase_event('e2','11111111-1111-4111-8111-111111111111','tx1','ei.cash.10000','SANDBOX','app','purchase');
do $$ begin if (select contributed_cents from public.wallets where user_id='11111111-1111-4111-8111-111111111111')<>2000000 then raise exception 'FAIL: duplicate receipt'; end if; end $$;
select public.apply_purchase_event('e3','11111111-1111-4111-8111-111111111111','tx1','ei.cash.10000','SANDBOX','app','refund');
select public.apply_purchase_event('e4','11111111-1111-4111-8111-111111111111','tx1','ei.cash.10000','SANDBOX','app','refund');
select public.apply_purchase_event('e5','11111111-1111-4111-8111-111111111111','tx2','ei.cash.10000','SANDBOX','app','refund');
select public.apply_purchase_event('e6','11111111-1111-4111-8111-111111111111','tx2','ei.cash.10000','SANDBOX','app','purchase');
do $$ begin
  if (select contributed_cents from public.wallets where user_id='11111111-1111-4111-8111-111111111111')<>1000000 then raise exception 'FAIL: refund ordering'; end if;
  if exists(select 1 from public.wallets w where w.cash_cents<>(select sum(amount_cents) from public.ledger where user_id=w.user_id)) then raise exception 'FAIL: ledger mismatch'; end if;
end $$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
update public.quotes set data=jsonb_set(data,'{expiresAt}',to_jsonb(now()-interval '1 second'));
set role authenticated;
do $$ begin
  begin perform public.place_trade('77777777-7777-4777-8777-777777777777','AAPL','buy',1,'33333333-3333-4333-8333-333333333333'); raise exception 'FAIL: expired quote'; exception when others then if sqlerrm<>'STALE_QUOTE' then raise; end if; end;
end $$;
reset role;
update public.quotes set data=jsonb_set(jsonb_set(data,'{expiresAt}',to_jsonb(now()+interval '1 hour')),'{marketOpen}','false');
set role authenticated;
do $$ begin
  begin perform public.place_trade('77777777-7777-4777-8777-777777777777','AAPL','buy',1,'33333333-3333-4333-8333-333333333333'); raise exception 'FAIL: closed market'; exception when others then if sqlerrm<>'MARKET_CLOSED' then raise; end if; end;
end $$;
reset role;
delete from auth.users where id='11111111-1111-4111-8111-111111111111';
do $$ begin if exists(select 1 from public.wallets where user_id='11111111-1111-4111-8111-111111111111') then raise exception 'FAIL: account cascade'; end if; end $$;
select 'Wallet, RLS, idempotency, refunds, quote expiry and deletion checks passed.' as result;
