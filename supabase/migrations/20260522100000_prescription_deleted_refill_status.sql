-- 長輩刪除已申請志工代領的藥單時，保留代領列並標記為 prescription_deleted
alter table public.prescriptions
  drop constraint if exists prescriptions_refill_status_check;

alter table public.prescriptions
  add constraint prescriptions_refill_status_check
  check (
    refill_status = any (
      array[
        'none'::text,
        'pending_collection'::text,
        'collecting'::text,
        'out_of_stock'::text,
        'prescription_deleted'::text
      ]
    )
  );

comment on column public.prescriptions.refill_status is
  'none | pending_collection | collecting | out_of_stock | prescription_deleted（長輩已刪藥單，志工需再次確認）';
