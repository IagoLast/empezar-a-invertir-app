begin;
insert into auth.users(id) values('00000000-0000-0000-0000-000000000099');
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000099';
select public.ensure_wallet();
select public.save_quote(jsonb_build_object('id','10000000-0000-0000-0000-000000000099','symbol','AAPL','kind','stock','source','Finnhub','currency','USD','priceCents',10000,'asOf',now(),'fetchedAt',now(),'expiresAt',now()+interval '15 minutes','marketOpen',false,'tradable',false,'averageDailyVolume',50000000));
set local role authenticated;
select public.submit_simulated_order('20000000-0000-0000-0000-000000000099','AAPL','buy',2,'10000000-0000-0000-0000-000000000099');
select public.submit_simulated_order('20000000-0000-0000-0000-000000000099','AAPL','buy',2,'10000000-0000-0000-0000-000000000099');
do $$ begin
 if (public.get_state()->>'reservedCashCents')::bigint<>20100 then raise exception 'Reservation duplicated'; end if;
 if (public.get_state()->>'cashCents')::bigint<>1000000 then raise exception 'Refresh executed a trade'; end if;
 begin perform public.submit_simulated_order('20000000-0000-0000-0000-000000000098','AAPL','buy',100,'10000000-0000-0000-0000-000000000099'); raise exception 'Overspending accepted';
 exception when raise_exception then if sqlerrm<>'INSUFFICIENT_CASH' then raise; end if; end;
end $$;
select set_config('test.original_execution', (select execute_at::text from public.simulated_orders where id='20000000-0000-0000-0000-000000000099'), true);
select public.submit_simulated_order('20000000-0000-0000-0000-000000000099','AAPL','buy',3,'10000000-0000-0000-0000-000000000099',9000,1);
do $$ begin
 if (select execute_at from public.simulated_orders where id='20000000-0000-0000-0000-000000000099')<>current_setting('test.original_execution')::timestamptz then raise exception 'Edit postponed execution'; end if;
 if (public.get_state()->>'reservedCashCents')::bigint<>27100 then raise exception 'Edit reservation incorrect'; end if;
 begin perform public.submit_simulated_order('20000000-0000-0000-0000-000000000099','AAPL','buy',4,'10000000-0000-0000-0000-000000000099',9000,1); raise exception 'Stale edit accepted';
 exception when raise_exception then if sqlerrm<>'ORDER_CHANGED' then raise; end if; end;
end $$;
reset role;
update public.simulated_orders set execute_at=now()-interval '1 second';
select public.execute_simulated_orders();
select public.execute_simulated_orders();
do $$ begin
 if (select count(*) from public.orders where request_id='20000000-0000-0000-0000-000000000099')<>1 then raise exception 'Duplicate execution'; end if;
 if (public.get_state()->>'cashCents')::bigint<>972900 then raise exception 'Wrong debit'; end if;
 if (public.get_state()->>'reservedCashCents')::bigint<>0 then raise exception 'Reservation not released'; end if;
end $$;
set local role authenticated;
select public.submit_simulated_order('30000000-0000-0000-0000-000000000099','AAPL','sell',3,'10000000-0000-0000-0000-000000000099');
do $$ begin
 begin perform public.submit_simulated_order('30000000-0000-0000-0000-000000000098','AAPL','sell',1,'10000000-0000-0000-0000-000000000099'); raise exception 'Overselling accepted';
 exception when raise_exception then if sqlerrm<>'INSUFFICIENT_UNITS' then raise; end if; end;
end $$;
select public.cancel_simulated_order('30000000-0000-0000-0000-000000000099',1);
select public.cancel_simulated_order('30000000-0000-0000-0000-000000000099',1);
reset role;
do $$ begin
 if (select units from public.positions where user_id=auth.uid() and symbol='AAPL')<>3 then raise exception 'Cancelled sell changed position'; end if;
end $$;
set local role authenticated;
do $$ begin
 begin perform public.execute_simulated_orders(); raise exception 'Client executed worker';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
insert into auth.users(id) values('00000000-0000-0000-0000-000000000098');
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000098';
set local role authenticated;
do $$ begin
 if exists(select 1 from public.simulated_orders) then raise exception 'Other account can read orders'; end if;
 begin perform public.cancel_simulated_order('30000000-0000-0000-0000-000000000099',1); raise exception 'Other account cancelled order';
 exception when raise_exception then if sqlerrm<>'INVALID_INPUT' then raise; end if; end;
end $$;
rollback;
