alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.item_photos enable row level security;
alter table public.item_documents enable row level security;
alter table public.inventory_invites enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "items_select_shared_inventory" on public.items;
create policy "items_select_shared_inventory"
on public.items
for select
to authenticated
using (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.inventory_id = items.inventory_id
    )
);

drop policy if exists "items_insert_shared_inventory" on public.items;
create policy "items_insert_shared_inventory"
on public.items
for insert
to authenticated
with check (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.inventory_id = items.inventory_id
    )
);

drop policy if exists "items_update_shared_inventory" on public.items;
create policy "items_update_shared_inventory"
on public.items
for update
to authenticated
using (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.inventory_id = items.inventory_id
    )
)
with check (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.inventory_id = items.inventory_id
    )
);

drop policy if exists "items_delete_shared_inventory" on public.items;
create policy "items_delete_shared_inventory"
on public.items
for delete
to authenticated
using (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.inventory_id = items.inventory_id
    )
);

drop policy if exists "item_photos_select_shared_inventory" on public.item_photos;
create policy "item_photos_select_shared_inventory"
on public.item_photos
for select
to authenticated
using (
    exists (
        select 1
        from public.items i
        join public.profiles p on p.inventory_id = i.inventory_id
        where i.id = item_photos.item_id
          and p.id = auth.uid()
    )
);

drop policy if exists "item_photos_insert_shared_inventory" on public.item_photos;
create policy "item_photos_insert_shared_inventory"
on public.item_photos
for insert
to authenticated
with check (
    exists (
        select 1
        from public.items i
        join public.profiles p on p.inventory_id = i.inventory_id
        where i.id = item_photos.item_id
          and p.id = auth.uid()
    )
);

drop policy if exists "item_photos_delete_shared_inventory" on public.item_photos;
create policy "item_photos_delete_shared_inventory"
on public.item_photos
for delete
to authenticated
using (
    exists (
        select 1
        from public.items i
        join public.profiles p on p.inventory_id = i.inventory_id
        where i.id = item_photos.item_id
          and p.id = auth.uid()
    )
);

drop policy if exists "item_documents_select_shared_inventory" on public.item_documents;
create policy "item_documents_select_shared_inventory"
on public.item_documents
for select
to authenticated
using (
    exists (
        select 1
        from public.items i
        join public.profiles p on p.inventory_id = i.inventory_id
        where i.id = item_documents.item_id
          and p.id = auth.uid()
    )
);

drop policy if exists "item_documents_insert_shared_inventory" on public.item_documents;
create policy "item_documents_insert_shared_inventory"
on public.item_documents
for insert
to authenticated
with check (
    exists (
        select 1
        from public.items i
        join public.profiles p on p.inventory_id = i.inventory_id
        where i.id = item_documents.item_id
          and p.id = auth.uid()
    )
);

drop policy if exists "item_documents_delete_shared_inventory" on public.item_documents;
create policy "item_documents_delete_shared_inventory"
on public.item_documents
for delete
to authenticated
using (
    exists (
        select 1
        from public.items i
        join public.profiles p on p.inventory_id = i.inventory_id
        where i.id = item_documents.item_id
          and p.id = auth.uid()
    )
);

drop policy if exists "inventory_invites_select_involved" on public.inventory_invites;
create policy "inventory_invites_select_involved"
on public.inventory_invites
for select
to authenticated
using (
    invited_email = lower(coalesce(auth.jwt() ->> 'email', ''))
    or invited_by_user_id = auth.uid()::text
);

drop policy if exists "inventory_invites_insert_shared_inventory" on public.inventory_invites;
create policy "inventory_invites_insert_shared_inventory"
on public.inventory_invites
for insert
to authenticated
with check (
    invited_by_user_id = auth.uid()::text
    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.inventory_id = inventory_invites.inventory_id
    )
);

drop policy if exists "inventory_invites_update_involved" on public.inventory_invites;
create policy "inventory_invites_update_involved"
on public.inventory_invites
for update
to authenticated
using (
    invited_email = lower(coalesce(auth.jwt() ->> 'email', ''))
    or invited_by_user_id = auth.uid()::text
)
with check (
    invited_email = lower(coalesce(auth.jwt() ->> 'email', ''))
    or invited_by_user_id = auth.uid()::text
);

drop policy if exists "storage_shared_inventory" on storage.objects;
create policy "storage_shared_inventory"
on storage.objects
for all
to authenticated
using (
    bucket_id = 'vault-files'
    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and split_part(storage.objects.name, '/', 1) = p.inventory_id
    )
)
with check (
    bucket_id = 'vault-files'
    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and split_part(storage.objects.name, '/', 1) = p.inventory_id
    )
);
