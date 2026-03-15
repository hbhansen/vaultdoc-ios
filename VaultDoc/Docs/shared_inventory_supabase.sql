alter table if exists public.profiles
    add column if not exists email text;

alter table if exists public.profiles
    add column if not exists inventory_id text;

update public.profiles
set inventory_id = id
where inventory_id is null;

update public.profiles
set email = lower(email)
where email is not null;

alter table if exists public.items
    add column if not exists inventory_id text;

update public.items
set inventory_id = user_id
where inventory_id is null;

create table if not exists public.inventory_invites (
    id uuid primary key,
    inventory_id text not null,
    invited_email text not null,
    invited_by_user_id text not null,
    invited_by_email text not null,
    status text not null default 'pending',
    created_at timestamptz not null default timezone('utc', now()),
    constraint inventory_invites_status_check
        check (status in ('pending', 'accepted', 'declined', 'revoked'))
);

create unique index if not exists inventory_invites_pending_unique_idx
    on public.inventory_invites (inventory_id, invited_email)
    where status = 'pending';

create index if not exists inventory_invites_invited_email_idx
    on public.inventory_invites (invited_email, status);

create index if not exists items_inventory_id_idx
    on public.items (inventory_id);

create index if not exists profiles_inventory_id_idx
    on public.profiles (inventory_id);

alter table public.profiles
    alter column inventory_id set not null;

alter table public.items
    alter column inventory_id set not null;
