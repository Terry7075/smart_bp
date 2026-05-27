# 物資代購 × 智慧小幫手 — 開發總覽

> **個人負責模組**（第五章）。登入、健康 OCR、志工藥單、交通占位等由其他組員負責。  
> **GitHub**：`https://github.com/Terry7075/smart_bp` · 分支 **`features-shop`**

---

## 1. 三種使用者（報告 vs 程式）

| 報告用語 | 程式角色 | 做什麼 | 不做什麼 |
|----------|----------|--------|----------|
| **長輩** | `elder` | 記需求、語音、柑仔店下單、小幫手 | — |
| **志工** | `volunteer` | **代購執行**：看單、改狀態、依據點採買 | 不看全據點營運報表 |
| **據點管理者** | `admin` | **看數據**：統計、滯留單、熱門品項、據點物品 | 不取代志工逐筆代購 |

**不必**再開第四個 App 或 `site_manager` 角色；口試說明「管理者＝監控面、志工＝執行面」即可。

---

## 2. 路由與程式對照

| 功能 | 路由 | 主要檔案 |
|------|------|----------|
| 柑仔店／下單 | `/shop` | `shop_page.dart` |
| 語音隨選（全聯一句話） | `/shop` 內展開區 | `widgets/shop_manual_voice_section.dart` |
| 語音記錄需求 | `/shop`、`/shop/demand-input` | `shop_voice_demand_bar.dart` |
| 需求輸入頁 | `/shop/demand-input` | `shop_demand_input_page.dart` |
| 全聯價格參考 | `/shop/prices` | `shop_price_page.dart` |
| 長輩訂單紀錄 | `/shop/orders` | `shop_elder_orders_page.dart` |
| 訂單詳情＋配送軸 | `/shop/orders/:id` | `shop_order_detail_page.dart` |
| 智慧小幫手 | `/assistant` | `assistant_page.dart` |
| 對話歷史 | `/assistant/history` | `assistant_chat_history_page.dart` |
| 志工代購清單 | `/volunteer/shop-orders` | `volunteer_shop_orders_page.dart` |
| 據點管理後台 | `/admin/dashboard` | `admin_dashboard_page.dart` |
| 家屬關懷 | `/family/home` | `family_home_page.dart` |

角色分流：`lib/core/router.dart`、`lib/features/auth/role_guard.dart`

---

## 3. 功能完成度（第五章）

圖例：**✅ 已完成** · **⚠️ 部分／展示級** · **❌ 未做（可寫報告未來工作）**

### 3.1 長輩端

| 功能 | 狀態 | 說明 |
|------|------|------|
| 目錄選品＋購物車下單 | ✅ | `orders` + `order_items` |
| 語音記需求（按住說話） | ✅ | `ShopVoiceDemandBar`、小幫手麥克風 |
| 語音＋字幕、全聯一句話隨選 | ✅ | `ShopManualVoiceSection` + `shop_manual_voice_parser.dart` |
| 全聯搜尋外開 pxbox | ✅ | `px_mart_links.dart` |
| 全聯價格參考頁 | ✅ | 需 DB 有 `price_references` 資料 |
| 常購推薦 | ✅ | 歷史訂單加總，非 ML |
| 訂單 Realtime／配送時間軸 | ✅ | `shop_orders_realtime_provider`、`order_delivery_events` |
| 全聯價格自動爬蟲 | ❌ | 手動維護或種子資料 |
| 線上付款 | ❌ | 報告未列為本期 |

### 3.2 智慧小幫手

| 功能 | 狀態 | 說明 |
|------|------|------|
| 五類意圖（買／查價／查看／取消／閒聊） | ✅ | `assistant_shop_intent_classifier.dart` |
| 三層匹配 L1→L2→L3 + 槽位 | ✅ | 單元測試語料 ≥90% |
| 寫入 `demand_records`、查 `price_references` | ✅ | `assistant_shop_action_service.dart` |
| 對話歷史＋意圖標籤 | ✅ | `assistant_chat_sessions` |
| 多輪追問（如「那代購呢」） | ✅ | `assistant_dialog_context.dart` |
| 代購進度／帶路（舊版三意圖） | ✅ | `assistant_intent.dart` + snapshot |
| **全 App 每頁教學＋一鍵帶路** | ⚠️ | 產品目標見 `.cursor/rules/assistant-product-goal.mdc`，覆蓋度依路由逐步補 |
| 閒聊接 Ollama | ⚠️ | 需 `--dart-define=ASSISTANT_CASUAL_AI=true` |
| 雲端 LLM 必開 | ❌ | 預設規則式，偏鄉可離線 |

### 3.3 志工端

| 功能 | 狀態 | 說明 |
|------|------|------|
| 訂單列表＋狀態更新 | ✅ | pending → processing → completed |
| 依據點分組展開 | ✅ | `ExpansionTile` |
| `demand_records` 草稿 Realtime | ✅ | `volunteer_demands_provider.dart` |
| 待辦優先排序 | ✅ | `ShopOrderPriority` |
| 報告寫的「柑仔店卡片看各長輩需求」 | ✅ | **在志工頁**，非長輩購物頁 |

### 3.4 據點管理者（admin）

| 功能 | 狀態 | 說明 |
|------|------|------|
| 訂單狀態統計、滯留 >24h | ✅ | `admin_providers.dart` |
| 熱門品項 Top5、需求草稿數 | ✅ | |
| 滯留單顯示長輩姓名 | ✅ | 點入訂單詳情 |
| **依據點篩選統計** | ❌ | 建議加分項 |
| **依長輩彙總（讀取服務故事）** | ❌ | 建議加分項 |
| **據點物品 App 內新增／編輯** | ❌ | 目前 `location_assets` 唯讀，Supabase 手動維護 |
| 志工服務量／績效報表 | ❌ | 寫入報告「未來工作」 |
| 匯出 PDF 報表 | ❌ | |

### 3.5 家屬端（延伸）

| 功能 | 狀態 | 說明 |
|------|------|------|
| 綁定長輩 | ✅ | `family_elder_links` |
| 查看長輩訂單 Realtime | ✅ | `family_home_page.dart` |
| 管理者與家屬聯動報表 | ❌ | 論述可寫，程式未串 |

### 3.6 後端／基礎建設

| 項目 | 狀態 | 說明 |
|------|------|------|
| Supabase Auth + RLS | ✅ | 與全 App 共用 |
| 第五章 SQL | ✅ | `supabase/chapter5_shop_assistant_schema.sql` |
| Realtime（orders、demand） | ✅ | |
| `chat_histories` 檢視 | ✅ | 對應 `assistant_chat_sessions` |
| 執行 SQL 順序 | ⚠️ | 新環境需手動跑（見下節） |

---

## 4. 尚未完整開發 — 建議優先順序

### 口試前「只改文件」即可

- 報告 **5.1.2 表 8**：據點管理者＝`admin` 監控，志工＝執行  
- **5.3.1**：「各長輩需求單」改為**志工端**檢視  
- **5.3.3**：加「完成度」欄（✅／⚠️／❌）  
- **5.4**：填入實際 `flutter test` 數字  

### 有時間可做小功能（性價比高）

1. Admin **依據點篩選**統計  
2. Admin **長輩 30 天訂單次數**（督導用）  
3. Admin **`location_assets` 簡易 CRUD**  
4. `price_references` 種子 SQL 或後台一鍵匯入  

### 建議本期不做

- 獨立「據點管理者」角色 + 複製志工 UI  
- 全聯價格爬蟲、線上金流  
- 跨四子系統統一儀表板  

### 全 App（非僅第五章）

- 首頁 **社區學習、交通** 等仍為 `print` 占位（`home_page.dart`）— 他組或後續  

---

## 5. Supabase SQL 執行順序（新電腦必做）

在 Supabase SQL Editor **依序**執行：

1. `supabase/orders_schema.sql`  
2. `supabase/orders_volunteer_update_rls.sql`  
3. `supabase/assistant_chat_schema.sql`  
4. `supabase/graduation_enhancement_schema.sql`  
5. **`supabase/chapter5_shop_assistant_schema.sql`**

連線設定在 `lib/main.dart`（與團隊共用同一 Supabase 專案）。

測試帳號 `profiles.role`：`elder` / `volunteer` / `admin` / `family`

---

## 6. 本機執行與測試

```bash
cd smart_bp-main   # 或 clone 後的目錄
flutter pub get

# Web Demo
flutter run -d chrome --web-port=8080

# 測試（口試可報告準確率）
flutter test test/assistant_shop_intent_test.dart
flutter test test/assistant_intent_test.dart
flutter test test/assistant_dialog_context_test.dart
flutter test test/shop_manual_voice_parser_test.dart
```

**iPhone 實機**：Xcode 開 `ios/Runner.xcworkspace` → Signing 選 Team → 選 iPhone Run。  
**Android APK**：`flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

---

## 7. 口試 Demo 建議路徑（約 5 分鐘）

1. **長輩**：柑仔店 → 語音隨選「全聯的鮮奶兩罐」→ 加入需求 → 送出  
2. **小幫手**：「雞蛋多少錢」「我要買米」→ 歷史看意圖標籤  
3. **志工**：`/volunteer/shop-orders` 依據點展開 → 改狀態 → 強調 Realtime  
4. **管理者**：`/admin/dashboard` 統計、滯留單、Top5（**解讀數據，不是代購**）

---

## 8. 模組目錄速查

| 模組 | 路徑 |
|------|------|
| 物資代購 | `lib/features/shop/` |
| 小幫手 | `lib/features/assistant/` |
| 家屬 | `lib/features/family/` |
| 管理後台 | `lib/features/admin/` |
| 志工代購頁 | `lib/features/volunteer/volunteer_shop_orders_page.dart` |
| 路由 | `lib/core/router.dart` |
| Cursor 產品目標 | `.cursor/rules/assistant-product-goal.mdc` |
| 報告第五章 | `docs/專題成果報告書初稿.md` |

---

## 9. 換電腦開發

```bash
git clone https://github.com/Terry7075/smart_bp.git
cd smart_bp
git checkout features-shop
flutter pub get
cd ios && pod install && cd ..   # 若要跑 iOS
```

- **程式碼**：Git 同步  
- **Cursor 對話**：不會雲端同步；重要結論寫進本文件或報告  
- **資料庫**：同一 Supabase，不用搬檔  

---

*最後更新：對齊 `features-shop` 分支（物資語音隨選、第五章 schema、admin 儀表板）。*
