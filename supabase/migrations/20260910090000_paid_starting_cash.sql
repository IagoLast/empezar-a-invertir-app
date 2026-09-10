-- New accounts start empty; preserve existing balances and historical ledger entries.
begin;
alter table public.wallets alter column cash_cents set default 0;
alter table public.wallets alter column contributed_cents set default 0;

create or replace function public.ensure_wallet() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
  if u is null then raise exception 'UNAUTHORIZED'; end if;
  insert into public.wallets(user_id) values(u) on conflict do nothing;
  return u;
end $$;

create or replace function public.apply_purchase_event(p_event text,p_user uuid,p_transaction text,p_product text,p_environment text,p_app text,p_kind text)
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

commit;
