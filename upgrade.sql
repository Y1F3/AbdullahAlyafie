-- Upgrade for Abdullah Alyafie personal website. Safe to run more than once.
-- Run this in Supabase SQL Editor using the same project already connected to config.js.

create table if not exists public.site_content (
  key text primary key,
  value text
);

create table if not exists public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  description text,
  category text,
  image_url text,
  link_url text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  description text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.experiences (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  organization text,
  description text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Add fields used by this version if the tables existed before the upgrade.
alter table public.site_content add column if not exists key text;
alter table public.site_content add column if not exists value text;
alter table public.portfolio_items add column if not exists title text;
alter table public.portfolio_items add column if not exists description text;
alter table public.portfolio_items add column if not exists category text;
alter table public.portfolio_items add column if not exists image_url text;
alter table public.portfolio_items add column if not exists link_url text;
alter table public.portfolio_items add column if not exists sort_order integer default 0;
alter table public.services add column if not exists title text;
alter table public.services add column if not exists description text;
alter table public.services add column if not exists sort_order integer default 0;
alter table public.experiences add column if not exists title text;
alter table public.experiences add column if not exists organization text;
alter table public.experiences add column if not exists description text;
alter table public.experiences add column if not exists sort_order integer default 0;
alter table public.admin_users add column if not exists user_id uuid;

create unique index if not exists site_content_key_unique_idx on public.site_content(key);
create index if not exists portfolio_items_sort_idx on public.portfolio_items(sort_order);
create index if not exists services_sort_idx on public.services(sort_order);
create index if not exists experiences_sort_idx on public.experiences(sort_order);

-- Seed the design controls without overwriting existing settings.
insert into public.site_content(key,value) values
('design_settings','{"bg":"#080d18","panel":"#0e1626","panel2":"#121d30","text":"#f4f5f7","muted":"#a7b0c1","gold":"#d7b76d","gold2":"#f1dba0","navy":"#101d32","fontFamily":"IBM Plex Sans Arabic","baseFontSize":16,"radius":22,"buttonRadius":10,"sectionSpacing":100,"maxWidth":1180}'),
('section_settings','[{"id":"hero","label":"الواجهة الرئيسية","visible":true,"order":1},{"id":"about","label":"نبذة عني","visible":true,"order":2},{"id":"works","label":"الأعمال والمشاريع","visible":true,"order":3},{"id":"services","label":"الخدمات","visible":true,"order":4},{"id":"experience","label":"الخبرات","visible":true,"order":5},{"id":"contact","label":"التواصل","visible":true,"order":6}]')
on conflict (key) do nothing;

-- RLS: only a signed-in user listed in admin_users may manage site content.
create or replace function public.is_site_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.admin_users a where a.user_id = auth.uid() or a.user_id is null and to_jsonb(a)->>'id' = auth.uid()::text) $$;

alter table public.site_content enable row level security;
alter table public.portfolio_items enable row level security;
alter table public.services enable row level security;
alter table public.experiences enable row level security;
alter table public.admin_users enable row level security;

drop policy if exists "public read site content" on public.site_content;
create policy "public read site content" on public.site_content for select to anon, authenticated using (true);
drop policy if exists "admin manage site content" on public.site_content;
create policy "admin manage site content" on public.site_content for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "public read portfolio" on public.portfolio_items;
create policy "public read portfolio" on public.portfolio_items for select to anon, authenticated using (true);
drop policy if exists "admin manage portfolio" on public.portfolio_items;
create policy "admin manage portfolio" on public.portfolio_items for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "public read services" on public.services;
create policy "public read services" on public.services for select to anon, authenticated using (true);
drop policy if exists "admin manage services" on public.services;
create policy "admin manage services" on public.services for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "public read experiences" on public.experiences;
create policy "public read experiences" on public.experiences for select to anon, authenticated using (true);
drop policy if exists "admin manage experiences" on public.experiences;
create policy "admin manage experiences" on public.experiences for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "admin can read admin list" on public.admin_users;
create policy "admin can read admin list" on public.admin_users for select to authenticated using (public.is_site_admin() or user_id = auth.uid());

-- Create/ensure public storage bucket used for portfolio and hero images.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('portfolio','portfolio',true,8388608,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public=true, file_size_limit=8388608, allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'];
drop policy if exists "public view portfolio images" on storage.objects;
create policy "public view portfolio images" on storage.objects for select to anon, authenticated using (bucket_id='portfolio');
drop policy if exists "admins upload portfolio images" on storage.objects;
create policy "admins upload portfolio images" on storage.objects for insert to authenticated with check (bucket_id='portfolio' and public.is_site_admin());
drop policy if exists "admins update portfolio images" on storage.objects;
create policy "admins update portfolio images" on storage.objects for update to authenticated using (bucket_id='portfolio' and public.is_site_admin()) with check (bucket_id='portfolio' and public.is_site_admin());
drop policy if exists "admins delete portfolio images" on storage.objects;
create policy "admins delete portfolio images" on storage.objects for delete to authenticated using (bucket_id='portfolio' and public.is_site_admin());
