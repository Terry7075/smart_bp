# 物資訂購與智慧小幫手 — 技術架構 v2

> **已 supersede**：口試與報告請改讀 [`shop_subsystem_architecture_v3.md`](./shop_subsystem_architecture_v3.md)（雙角色、Hybrid NLU、志工 Tab 4 數據總覽）。

## 五階段能力

| 階段 | 模組 | 演算法／技術 |
|------|------|----------------|
| 1 | Product Normalization Engine (PNE) | 多層同義詞實體解析、槽位填充 |
| 2 | Recommendation Engine (RE) | 加權線性推薦（社區／價格／志工） |
| 3 | Purchase Batch Aggregator (PBA) | 貪婪聚合 O(n) |
| 4 | Purchase Route Planner (PRP) | Nearest Neighbor TSP 近似 |
| 5 | 論文指標 E1–E6 | 見下方 |

## 資料表（Supabase）

- `product_categories`, `product_brands`, `product_synonyms`
- `purchase_events`, `brand_recommendation_stats`, `recommendation_logs`
- `volunteer_purchase_batches`, `volunteer_purchase_batch_lines`, `volunteer_purchase_batch_members`
- `purchase_locations`；`location_points.lat/lng`

Migration：`supabase/migrations/20260601000000_product_catalog_and_intelligence.sql`

## 程式入口

- `lib/features/shop/data/product_normalization_engine.dart`
- `lib/features/shop/data/recommendation_engine.dart`
- `lib/features/shop/data/purchase_batch_aggregator.dart`
- `lib/features/shop/data/purchase_batch_repository.dart`
- `lib/features/shop/data/purchase_route_planner.dart`
- 志工 UI：`lib/features/volunteer/widgets/volunteer_purchase_batch_panel.dart`

## 實驗指標（論文）

| 編號 | 指標 | 目標 |
|------|------|------|
| E1 | 標準化準確率（100 句） | category ≥90%、brand ≥85% |
| E2 | 推薦 Top-3 Hit Rate | ≥70% |
| E3 | 批次壓縮率 | ≥40% |
| E4 | 路線 vs 隨機順序 | 節省 ≥15% |
| E5 | 語音→寫入 P95 | <800ms |
| E6 | 離線冪等重送 | 無重複單 |

## 部署

在 Supabase SQL Editor 依序執行既有 `chapter5_shop_assistant_schema.sql` 後，再執行上述 migration。
