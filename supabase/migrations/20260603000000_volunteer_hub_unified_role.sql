-- 據點管理者併入志工：admin 與 volunteer 共用訂單讀取、據點物品管理

drop policy if exists "orders_select_volunteer" on public.orders;
create policy "orders_select_volunteer"
  on public.orders for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role::text in ('volunteer', 'admin')
    )
  );

drop policy if exists "order_items_select_volunteer" on public.order_items;
create policy "order_items_select_volunteer"
  on public.order_items for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role::text in ('volunteer', 'admin')
    )
  );

drop policy if exists "location_assets_admin" on public.location_assets;
drop policy if exists "location_assets_hub_manager" on public.location_assets;
create policy "location_assets_hub_manager"
  on public.location_assets for all to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role::text in ('volunteer', 'admin')
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role::text in ('volunteer', 'admin')
    )
  );
