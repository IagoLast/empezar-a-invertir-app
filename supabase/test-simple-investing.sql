-- Disposable database only. Verify immediate fills, retries, rollback and ownership.
begin;
insert into auth.users(id) values('00000000-0000-0000-0000-000000000088'),('00000000-0000-0000-0000-000000000087');
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000088';
select public.ensure_wallet();
select public.save_quote(jsonb_build_object('id','10000000-0000-0000-0000-000000000088','symbol','ITX.MC','kind','stock','source','EODHD','currency','USD','priceCents',10000,'asOf',now()-interval '1 day','fetchedAt',now(),'expiresAt',now()+interval '15 minutes','marketOpen',false,'tradable',false));
set local role authenticated;
select public.submit_simulated_order('20000000-0000-0000-0000-000000000088','ITX.MC','buy',2,'10000000-0000-0000-0000-000000000088');
select public.submit_simulated_order('20000000-0000-0000-0000-000000000088','ITX.MC','buy',2,'10000000-0000-0000-0000-000000000088');
do $$ begin
 if (public.get_state()->>'cashCents')::bigint<>979900 then raise exception 'Incorrect or duplicate debit'; end if;
 if (public.get_state()->>'reservedCashCents')::bigint<>0 then raise exception 'Immediate fill left a reservation'; end if;
 if (select count(*) from public.orders where request_id='20000000-0000-0000-0000-000000000088')<>1 then raise exception 'Missing or duplicate history'; end if;
 if (select units from public.positions where user_id=auth.uid() and symbol='ITX.MC')<>2 then raise exception 'Position not updated'; end if;
 if (select status from public.simulated_orders where id='20000000-0000-0000-0000-000000000088')<>'executed' then raise exception 'Order left pending'; end if;
 begin perform public.submit_simulated_order('20000000-0000-0000-0000-000000000086','ITX.MC','buy',100,'10000000-0000-0000-0000-000000000088'); raise exception 'Overspending accepted';
 exception when raise_exception then if sqlerrm<>'INSUFFICIENT_CASH' then raise; end if; end;
 begin perform public.submit_simulated_order('20000000-0000-0000-0000-000000000088','ITX.MC','buy',3,'10000000-0000-0000-0000-000000000088'); raise exception 'Retry changed completed order';
 exception when raise_exception then if sqlerrm<>'ORDER_FINISHED' then raise; end if; end;
 begin perform public.execute_simulated_orders_for_user(auth.uid()); raise exception 'Client invoked worker';
 exception when insufficient_privilege then null; end;
end $$;
select public.submit_simulated_order('30000000-0000-0000-0000-000000000088','ITX.MC','sell',2,'10000000-0000-0000-0000-000000000088');
do $$ begin
 if (public.get_state()->>'cashCents')::bigint<>999800 then raise exception 'Sell credit incorrect'; end if;
 if exists(select 1 from public.positions where user_id=auth.uid() and symbol='ITX.MC') then raise exception 'Sold position remains'; end if;
 begin perform public.submit_simulated_order('30000000-0000-0000-0000-000000000086','ITX.MC','sell',1,'10000000-0000-0000-0000-000000000088'); raise exception 'Overselling accepted';
 exception when raise_exception then if sqlerrm<>'INSUFFICIENT_UNITS' then raise; end if; end;
end $$;
reset role;
update public.quotes set data=jsonb_set(data,'{source}','"Alpha Vantage"') where id='10000000-0000-0000-0000-000000000088';
set local role authenticated;
select public.submit_simulated_order('40000000-0000-0000-0000-000000000088','ITX.MC','buy',1,'10000000-0000-0000-0000-000000000088');
reset role;
update public.quotes set data=jsonb_set(data,'{source}','"Untrusted"') where id='10000000-0000-0000-0000-000000000088';
set local role authenticated;
do $$ begin
 begin perform public.submit_simulated_order('50000000-0000-0000-0000-000000000088','ITX.MC','buy',1,'10000000-0000-0000-0000-000000000088'); raise exception 'Untrusted quote accepted';
 exception when raise_exception then if sqlerrm<>'STALE_QUOTE' then raise; end if; end;
end $$;
reset role;
update public.quotes set data=data || jsonb_build_object('source','EODHD','expiresAt',now()-interval '1 second') where id='10000000-0000-0000-0000-000000000088';
set local role authenticated;
do $$ begin
 begin perform public.submit_simulated_order('50000000-0000-0000-0000-000000000088','ITX.MC','buy',1,'10000000-0000-0000-0000-000000000088'); raise exception 'Expired quote accepted';
 exception when raise_exception then if sqlerrm<>'STALE_QUOTE' then raise; end if; end;
end $$;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000087';
do $$ begin
 if exists(select 1 from public.simulated_orders) then raise exception 'Other user can read orders'; end if;
 begin perform public.submit_simulated_order('20000000-0000-0000-0000-000000000088','ITX.MC','buy',2,'10000000-0000-0000-0000-000000000088'); raise exception 'Other user reused order';
 exception when raise_exception then if sqlerrm<>'INVALID_INPUT' then raise; end if; end;
end $$;
rollback;
