-- =============================================================================
-- 志工可更新 `orders.status`（接單／Double-check 完成／取消）
-- =============================================================================
-- 前提：`profiles.role = 'volunteer'` 與 App 一致；`order_status` enum 已存在。
-- Demo：志工可改「任意」訂單的 status；上線請改為 RPC 或限制欄位。
-- =============================================================================

drop policy if exists "orders_update_volunteer" on public.orders;
create policy "orders_update_volunteer"
on public.orders for update
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role::text = 'volunteer'
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role::text = 'volunteer'
  )
);

-- 若長輩也需要更新自己的訂單（例如取消），可另加 policy，此檔不覆蓋既有 insert/select。
