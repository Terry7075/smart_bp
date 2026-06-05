# 物資代購 × 智慧小幫手 — 開發總覽

> **個人負責模組**（第五章）。登入、健康 OCR、志工藥單、交通占位等由其他組員負責。  
> **GitHub**：`https://github.com/Terry7075/smart_bp` · 分支 **`features-shop`**

---

## 1. 兩種登入角色（報告 vs 程式）

| 報告用語 | 程式角色 | 做什麼 |
|----------|----------|--------|
| **長輩** | `elder` | 記需求、語音、柑仔店下單、Hybrid NLU 小幫手、三卡推薦 |
| **志工** | `volunteer` | **代購執行**（看單、今日採買清單、履行狀態）＋ **據點數據總覽**（主控台 Tab 4） |

**口試敘事**：物資子系統僅 **長輩 + 志工** 兩種登入；據點統計、滯留單、熱門品項、據點資產檢視已併入志工 `/volunteer-dashboard?tab=3`，**不另開據點管理者 App**。

**程式相容**：`profiles.role` 仍可有 `admin`（RLS／測試帳號）；登入 `admin` 會導向志工主控台數據 Tab。`family` 為延伸模組，第五章主敘事可不提。

---

## 2. 路由與程式對照

| 功能 | 路由 | 主要檔案 |
|------|------|----------|
| **柑仔店（唯一主入口）** | `/shop` | `shop_page.dart`、`shop_primary_demand_section.dart` |
| 語音 → 品牌確認 → 送出志工 | `/shop` 上方主區 | `shop_supply_dialogue_provider.dart`、`brand_choice_list.dart` |
| 常用物資點選 | `/shop` | `shop_supply_wizard.dart` |
| 語音隨選（全聯一句話） | `/shop` 目錄區（可選） | `shop_manual_voice_section.dart` |
| 舊路由相容 | `/shop/demand-input` | 自動 redirect → `/shop` |
| 全聯價格參考 | `/shop/prices` | `shop_price_page.dart` |
| 長輩訂單紀錄 | `/shop/orders` | `shop_elder_orders_page.dart` |
| 訂單詳情＋配送軸 | `/shop/orders/:id` | `shop_order_detail_page.dart` |
| 智慧小幫手 | `/assistant` | `assistant_page.dart`、`hybrid_nlu_orchestrator.dart` |
| 對話歷史 | `/assistant/history` | `assistant_chat_history_page.dart` |
| 志工物資／今日採買 | `/volunteer/shop-orders` | `volunteer_shop_orders_page.dart`、`volunteer_daily_shopping_list_panel.dart` |
| 志工數據總覽 | `/volunteer-dashboard?tab=3` | `volunteer_hub_analytics_tab.dart` |
| 舊管理路由（跳轉） | `/admin/dashboard` | → `volunteer-dashboard?tab=3` |
| 家屬關懷（延伸） | `/family/home` | `family_home_page.dart` |

角色分流：`lib/core/router.dart`、`lib/features/auth/role_guard.dart`（志工 Hub 含 `volunteer` 與 `admin`）

---

## 3. 功能完成度（第五章）

圖例：**✅ 已完成** · **⚠️ 部分／展示級** · **❌ 未做（可寫報告未來工作）**

### 3.1 長輩端

| 功能 | 狀態 | 說明 |
|------|------|------|
| 目錄選品＋購物車下單 | ✅ | `orders` + `order_items` |
| 語音記需求（按住說話） | ✅ | `ShopVoiceDemandBar`（Hybrid NLU）、小幫手麥克風 |
| 語音＋字幕、全聯一句話隨選 | ✅ | `ShopManualVoiceSection` + `shop_manual_voice_parser.dart` |
| Hybrid NLU + 澄清對話 | ✅ | `HybridNluOrchestrator`、`clarification_sessions` |
| 三卡個人化推薦 | ✅ | 柑仔店 `ShopPersonalizedRecommendations` + 小幫手 chip |
| 全聯搜尋外開 pxbox | ✅ | `px_mart_links.dart` |
| 全聯價格參考頁 | ✅ | 需 DB 有 `price_references` 資料 |
| 訂單 Realtime／配送時間軸 | ✅ | `shop_orders_realtime_provider` |
| 全聯價格自動爬蟲 | ❌ | 手動維護或種子資料 |
| 線上付款 | ❌ | 報告未列為本期 |

### 3.2 智慧小幫手

| 功能 | 狀態 | 說明 |
|------|------|------|
| 核心五類意圖 + 延伸（缺貨建議、查訂單狀態） | ✅ | `assistant_shop_intent_classifier.dart`、`shop_utterance_handler.dart` |
| Hybrid NLU（規則 + 低信心 Edge） | ✅ | `parse_shop_nlu` Edge，門檻 0.75 |
| 多輪澄清（規格／便宜／上次買的） | ✅ | `clarification_sessions` 讀寫 + resume |
| 寫入 `demand_records`、查 `price_references` | ✅ | `assistant_shop_action_service.dart` |
| 對話歷史＋意圖標籤 | ✅ | `assistant_chat_sessions` |
| 閒聊（Gemini Edge） | ✅ | `assistant_casual_chat`；離線降級模板；關閉雲端：`ASSISTANT_CASUAL_GEMINI=false` |
| FCM 推播到裝置 | ✅ Android-only | `firebase_messaging` + `send_shop_push`；iOS 僅 Realtime／本機通知，見 [FCM_SETUP.md](FCM_SETUP.md) |

### 3.3 志工端

| 功能 | 狀態 | 說明 |
|------|------|------|
| 訂單列表＋狀態更新 | ✅ | pending → processing → completed |
| 依據點分組展開 | ✅ | `ExpansionTile` |
| 今日採買清單 RPC | ✅ | `get_daily_shopping_list` |
| 品項履行 FSM | ⚠️ | 志工 sheet + 長輩訂單詳情 Chip；訂單級狀態仍並行 |
| 主控台「數據總覽」Tab | ✅ | 統計、滯留單、Top5、`location_assets` |
| GPS 路線規劃 UI | ❌ | 已自採買主流程移除；程式模組保留 |

### 3.4 後端／基礎建設

| 項目 | 狀態 | 說明 |
|------|------|------|
| Supabase Auth + RLS | ✅ | 志工/admin 統一訂單與資產政策（`20260603`） |
| 商品語意庫 | ✅ | `product_items`、`product_aliases` |
| Realtime（orders、demand） | ✅ | migration `20260607` 冪等加入；未跑則 Dashboard 手動開 |
| 離線佇列 | ✅ | `flush` 僅同步草稿；送出須柑仔店按鈕 |
| 遷移執行順序 | ✅ | 見 `supabase/DEPLOY.md`（階段 A～C 完整順序） |
| 團隊建置 | ✅ | [TEAM_SETUP.md](TEAM_SETUP.md) |

---

## 4. 報告／口試對齊要點

- **表 8**：僅長輩 + 志工；統計在志工 Tab 4，非獨立管理者系統  
- **5.3.1**：「各長輩需求」在 **志工頁** 檢視，非長輩柑仔店頁  
- **5.4**：列出 `hybrid_nlu_orchestrator_test` 與雙軌狀態限制  
- 架構細節：`docs/shop_subsystem_architecture_v3.md`

---

## 5. Supabase SQL 執行順序

見 **`supabase/DEPLOY.md`**（階段 A 基礎 schema → B1～B8 migrations → C1 查價種子）。新電腦請先讀 **[TEAM_SETUP.md](TEAM_SETUP.md)**。

測試帳號 `profiles.role`：`elder` / `volunteer`（主敘事）；`admin` 導向志工 Hub；`family` 延伸。

---

## 6. 本機執行與測試

```bash
cd smart_bp-main
flutter pub get
flutter test test/hybrid_nlu_orchestrator_test.dart
flutter test test/assistant_shop_intent_test.dart
flutter test test/shop_manual_voice_parser_test.dart
```

---

## 7. 口試 Demo 建議路徑（約 5 分鐘）

見 **[DEMO_SCRIPT.md](DEMO_SCRIPT.md)**：柑仔店語音 → 品牌確認 → 送出志工 → 志工接單 →（可選）家屬／我的需求單 → 數據總覽 Tab。

---

## 8. 模組目錄速查

| 模組 | 路徑 |
|------|------|
| 物資代購 | `lib/features/shop/` |
| 小幫手 | `lib/features/assistant/` |
| 志工 Hub | `lib/features/volunteer/`（含 `volunteer_hub_analytics_tab.dart`） |
| 報告第五章 | `docs/專題成果報告書初稿.md` |
| 架構 v3 | `docs/shop_subsystem_architecture_v3.md` |

---

*最後更新：TEAM_SETUP、完整 DEPLOY 順序、離線文案、Realtime migration、查價 Demo 種子。*
