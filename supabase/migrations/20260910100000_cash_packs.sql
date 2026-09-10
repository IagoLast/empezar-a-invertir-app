-- Amounts are virtual USD cents; retain historical products for refunds.
begin;
insert into public.purchase_products(id, credit_cents) values
  ('ei.cash.1000', 100000),
  ('ei.cash.1000000', 100000000)
on conflict (id) do update set credit_cents = excluded.credit_cents;
commit;
