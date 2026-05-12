# V2 全工程 Flutter Analyze 体检报告

**日期**: 2026-05-07 | **工程**: `C:\projects\mls\app\mls_app` | **Flutter**: 3.41.7

---

## 总数统计

| 级别 | 数量 |
|---|---|
| **error** | 1 |
| **warning** | 5 |
| **info** | 25 |
| **合计** | **31** |

---

## 1. Error（1 条）

### 1.1 test/widget_test.dart — MyApp 类不存在

| 文件:行号 | `test/widget_test.dart:16:35` |
|---|---|
| 描述 | `The name 'MyApp' isn't a class` — V8.4 §六🟡15 登债 |
| 影响 | 仅 `flutter test`，不影响 build/run |
| 优先级 | 🟡 50 户以内不修 |

---

## 2. Warning（5 条）

### 2.1 Unused import（3 条）

| 文件:行号 | 描述 |
|---|---|
| `app_router.dart:3:8` | Unused import: `'../screens/home_screen.dart'` |
| `api_client.dart:1:8` | Unused import: `'package:flutter/material.dart'` |
| `photo_picker.dart:1:8` | Unused import: `'dart:io'` |

### 2.2 Unused element / variable（2 条）

| 文件:行号 | 描述 |
|---|---|
| `bottom_nav.dart:76:7` | `_PlaceholderPage` class 声明但从未引用 |
| `direct_showing_create_screen.dart:129:13` | Local variable `showingId` 声明后未使用 |

---

## 3. Info（25 条）

### 3.1 Deprecated API（9 条）

| 文件:行号 | 已废弃 API | 替代方案 |
|---|---|---|
| `customer_create_screen.dart:100,110` | `groupValue` (Radio) | `RadioGroup` ancestor |
| `customer_create_screen.dart:104,114` | `onChanged` (Radio) | `RadioGroup` |
| `showing_request_detail_screen.dart:1150` | `groupValue` (Radio) | `RadioGroup` |
| `showing_request_detail_screen.dart:1154` | `onChanged` (Radio) | `RadioGroup` |
| `listing_create_screen.dart:280` | `value` (DropdownButtonFormField) | `initialValue` |
| `community_picker.dart:399` | `value` (DropdownButtonFormField) | `initialValue` |
| `settlement_detail_screen.dart:73` | `onPopInvoked` | `onPopInvokedWithResult` |

### 3.2 Null-aware marker style（6 条）

| 文件:行号 | 描述 |
|---|---|
| `community_service.dart:35` | `if (x != null)` → use `?` null-aware marker |
| `community_service.dart:36` | 同上 |
| `transaction_service.dart:76` | 同上 |
| `transaction_service.dart:77` | 同上 |
| `transaction_service.dart:78` | 同上 |
| `transaction_service.dart:140` | 同上 |

### 3.3 Unnecessary underscores（6 条）

| 文件:行号 | 描述 |
|---|---|
| `settlement_pending_screen.dart:68` | `__` → `_` |
| `showing_pending_confirm_screen.dart:89` | `__` → `_` |
| `showing_request_create_screen.dart:520` | `__` → `_` |
| `transaction_pending_la_screen.dart:95` | `__` → `_` |
| `base64_image.dart:47` (×2) | `__` → `_` |

### 3.4 其他（4 条）

| 文件:行号 | Lint | 描述 |
|---|---|---|
| `showing_request_detail_screen.dart:195` | `use_build_context_synchronously` | BuildContext 跨 async gap |
| `photo_picker.dart:2` | `unnecessary_import` | `dart:typed_data` 被 `flutter/foundation.dart` 覆盖 |
| `progress_tracker.dart:30` | `prefer_const_constructors_in_immutables` | @immutable class 构造器应声明 const |
| `filter_sheet.dart:7` | `unintended_html_in_doc_comment` | 文档注释中 `<>` 被解析为 HTML |

---

## 4. 按文件分布

| 文件 | error | warning | info | 合计 |
|---|---|---|---|---|
| `customer_create_screen.dart` | 0 | 0 | 4 | 4 |
| `transaction_service.dart` | 0 | 0 | 4 | 4 |
| `showing_request_detail_screen.dart` | 0 | 0 | 3 | 3 |
| `photo_picker.dart` | 0 | 1 | 1 | 2 |
| `base64_image.dart` | 0 | 0 | 2 | 2 |
| `community_service.dart` | 0 | 0 | 2 | 2 |
| `showing_pending_confirm_screen.dart` | 0 | 0 | 1 | 1 |
| `showing_request_create_screen.dart` | 0 | 0 | 1 | 1 |
| `settlement_pending_screen.dart` | 0 | 0 | 1 | 1 |
| `transaction_pending_la_screen.dart` | 0 | 0 | 1 | 1 |
| `listing_create_screen.dart` | 0 | 0 | 1 | 1 |
| `community_picker.dart` | 0 | 0 | 1 | 1 |
| `settlement_detail_screen.dart` | 0 | 0 | 1 | 1 |
| `filter_sheet.dart` | 0 | 0 | 1 | 1 |
| `progress_tracker.dart` | 0 | 0 | 1 | 1 |
| `direct_showing_create_screen.dart` | 0 | 1 | 0 | 1 |
| `bottom_nav.dart` | 0 | 1 | 0 | 1 |
| `app_router.dart` | 0 | 1 | 0 | 1 |
| `api_client.dart` | 0 | 1 | 0 | 1 |
| `test/widget_test.dart` | 1 | 0 | 0 | 1 |

---

## 5. 优先修复建议

| 优先级 | 类别 | 数量 | 说明 |
|---|---|---|---|
| 🔴 | Error | 1 | `widget_test.dart` — 已知登债，50 户以内不修 |
| 🟡 | Warning (unused import) | 3 | 一键删除，0 风险 |
| 🟡 | Warning (unused element) | 2 | 一键删除，0 风险 |
| 🟢 | Deprecated API | 9 | Flutter 3.41+ 新 API，渐进迁移 |
| 🟢 | Style/Other | 16 | 纯 lint 警告，无功能影响 |

---

**生成方式**: `flutter analyze` + `dart analyze` 全工程扫描，结果一致（31 issues）。
