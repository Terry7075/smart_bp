-- 家屬綁定改為「需長者同意」
--
-- 背景（安全性問題）：
--   原本家屬只要知道長者 UUID 就能 insert family_elder_links 並設 status='active'，
--   立即讀到該長者的代購訂單，沒有任何長者同意步驟。
--
-- 修正策略：
--   1. App 端改為以 status='pending' 建立綁定請求（見 family_links_repository）。
--   2. orders / order_items 的 family select policy 已要求 status='active'，
--      因此 pending 請求讀不到任何資料；必須長者核准後才生效。
--   3. 本 migration 新增「長者可更新 / 刪除自己 incoming 綁定」的 RLS policy，
--      讓長者能在 App 內同意（status→active）或拒絕（刪除）。
--      家屬端維持只能 insert / 刪除自己建立的列，無法自行升級為 active。

-- 長者可核准（或改狀態）自己被綁定的列。
drop policy if exists "family_links_update_elder" on public.family_elder_links;
create policy "family_links_update_elder"
on public.family_elder_links for update
using (elder_user_id = auth.uid())
with check (elder_user_id = auth.uid());

-- 長者可拒絕（刪除）綁定請求。
drop policy if exists "family_links_delete_elder" on public.family_elder_links;
create policy "family_links_delete_elder"
on public.family_elder_links for delete
using (elder_user_id = auth.uid());

notify pgrst, 'reload schema';
