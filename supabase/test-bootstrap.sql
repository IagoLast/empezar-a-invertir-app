-- Test-only Supabase Auth surface for a disposable PostgreSQL database.
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth,public to anon,authenticated,service_role;
grant execute on function auth.uid() to anon,authenticated,service_role;
