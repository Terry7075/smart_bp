# 物資代購 × 智慧小幫手（個人負責模組）

本文件說明 **柑仔店物資代購** 與 **AI 小幫手** 的架構、部署與口試重點。登入、健康 OCR、志工藥單等由其他組員負責。

## 模組路徑

| 模組 | 路徑 |
|------|------|
| 物資代購 | `lib/features/shop/` |
| 小幫手 | `lib/features/assistant/` |
| 家屬代購延伸 | `lib/features/family/` |
| 訂單後台統計 | `lib/features/admin/` |

## Supabase SQL 執行順序

1. `supabase/orders_schema.sql`
2. `supabase/orders_volunteer_update_rls.sql`
3. `supabase/assistant_chat_schema.sql`
4. `supabase/graduation_enhancement_schema.sql`（配送事件、家屬綁定、管理員 RLS）
5. **`supabase/chapter5_shop_assistant_schema.sql`**（第五章：`demand_records`、`price_references`、`location_points`、`chat_histories` 檢視）

## 物資代購重點

- **下單**：`ShopOrdersRepository.createOrder` → `orders` + `order_items` + `order_delivery_events(created)`
- **配送時間軸**：`order_delivery_events` + `OrderDeliveryTimeline`
- **Realtime**：`shop_orders_realtime_provider.dart` 訂閱 `orders` 變更後重載明細（長輩／志工／家屬／訂單詳情）
- **志工待辦排序**：`ShopOrderPriority`（待處理越久、處理中越久未更新者越靠前）
- **常購推薦**：依歷史 `order_items` 加總，非 ML

## 小幫手重點（第五章）

- **五類意圖**：`assistant_shop_intent_classifier.dart`（記錄需求／查價／查看／取消／閒聊）
- **三層匹配**：L1 關鍵字 → L2 正則 → L3 同義詞；**槽位**解析商品與數量
- **動作**：`assistant_shop_action_service.dart` → `demand_records` / `price_references`
- **舊版意圖**：`assistant_intent.dart`（casual / systemData / appGuide，查代購進度、帶路）
- **多輪追問**：`assistant_dialog_context.dart`（例：「那代購呢」→「代購訂單進度」）
- **Grounded 回覆**：`assistant_reply_service.dart` 只讀 `AssistantSnapshot`（含 `recentOrders`）
- **語氣**：`assistant_reply_orchestrator.dart` + `assistant_tone.dart`
- **語音**：`speech_to_text`（`assistant_voice_provider.dart`）
- **歷史**：`assistant_chat_sessions`（`assistant_history_repository.dart`）
- **可選本機 LLM**：`flutter run --dart-define=ASSISTANT_CASUAL_AI=true`（需 Ollama）

## 測試

```bash
flutter test test/assistant_shop_intent_test.dart
flutter test test/assistant_intent_test.dart
flutter test test/assistant_dialog_context_test.dart
```

意圖語料：`test/assistant_intent_corpus.dart`（口試可報告準確率與混淆樣本）。

## 執行 Web Demo

```bash
flutter pub get
flutter run -d chrome --web-port=8080
```

## 口試建議說法

1. 代購狀態來自 **PostgreSQL + RLS**，小幫手回答標註「資料來自系統」與更新時間。
2. 意圖分類為 **可解釋規則 + 單元測試語料**，非黑箱 ML。
3. Realtime 讓長輩／家屬不必手動重整即可看到志工更新配送。
