-- Android-only FCM：加速 Edge 依 platform 查 token
create index if not exists device_tokens_user_platform_idx
  on public.device_tokens (user_id, platform);

comment on table public.device_tokens is
  'FCM 裝置 token；本專題遠端推播僅使用 platform=android';
