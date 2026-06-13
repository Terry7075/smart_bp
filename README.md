# 明德 e 達人（smart_bp）

Flutter + Supabase 社區長輩整合平台（用藥、檔案、物資代購、交通等）。

## 個人負責（第五章：物資代購 + 智慧小幫手）

完整說明、**功能完成度**、未完成清單、Demo 路徑：

**[docs/SHOP_ASSISTANT_README.md](docs/SHOP_ASSISTANT_README.md)**

新電腦建置（Firebase、SQL 順序、測試帳號）：**[docs/TEAM_SETUP.md](docs/TEAM_SETUP.md)**

| 快速指令 | |
|----------|--|
| 安裝 | `flutter pub get` |
| Web Demo | `flutter run -d chrome --web-port=8080` |
| 意圖測試 | `flutter test test/assistant_shop_intent_test.dart` |
| Git 分支 | `features-shop` |
| 遠端 | https://github.com/Terry7075/smart_bp |

## 其他組員模組（簡述）

- 登入／角色：`lib/features/auth/`
- 健康 OCR／藥單：其他組員
- 志工藥單主控：`lib/features/volunteer/volunteer_dashboard.dart`
- 首頁交通／學習等：部分仍為占位（見開發總覽）

## Supabase

連線見 `lib/main.dart`。SQL 執行順序見 [docs/SHOP_ASSISTANT_README.md §5](docs/SHOP_ASSISTANT_README.md#5-supabase-sql-執行順序新電腦必做)。
