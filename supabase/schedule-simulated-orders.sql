-- Run after the migration in Supabase. The worker needs no client connection.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('execute-simulated-orders', '10 seconds', 'select public.execute_simulated_orders()');
