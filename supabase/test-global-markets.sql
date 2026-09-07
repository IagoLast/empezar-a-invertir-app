-- Run after test-wallet.sql in the same disposable database.
insert into auth.users values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
set role service_role;
select public.quote_cache('ITX.MC');
select public.save_quote(jsonb_build_object('id','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'symbol','ITX.MC','kind','stock','name','Inditex','priceCents',5500,'currency','USD',
  'nativePrice',50,'nativeCurrency','EUR','exchangeRate',1.1,'marketOpen',true,'tradable',true,
  'expiresAt',now()+interval '15 minutes','asOf',now(),'fetchedAt',now()));
reset role;
set role authenticated;
select public.place_trade('cccccccc-cccc-4ccc-8ccc-cccccccccccc','ITX.MC','buy',2,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
select public.place_trade('cccccccc-cccc-4ccc-8ccc-cccccccccccc','ITX.MC','buy',2,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
do $$ begin
  if (select cash_cents from public.wallets) <> 988900 then raise exception 'FAIL: converted settlement or duplicate trade'; end if;
  if not exists(select 1 from jsonb_array_elements(public.get_state()->'quotes') q where q->>'symbol'='ITX.MC' and q->>'name'='Inditex') then raise exception 'FAIL: missing international holding quote'; end if;
  begin perform public.save_quote('{}'); raise exception 'FAIL: authenticated quote forgery'; exception when insufficient_privilege then null; end;
  begin perform public.quote_cache('ITX.MC'); raise exception 'FAIL: authenticated quote cache'; exception when insufficient_privilege then null; end;
end $$;
select public.place_trade('dddddddd-dddd-4ddd-8ddd-dddddddddddd','ITX.MC','sell',2,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
do $$ begin
  if exists(select 1 from public.positions) then raise exception 'FAIL: position not sold'; end if;
  if (select cash_cents from public.wallets) <> 999800 then raise exception 'FAIL: sale settlement'; end if;
end $$;
reset role;
select 'International registration, USD settlement, idempotency, holdings and selling checks passed.' as result;
