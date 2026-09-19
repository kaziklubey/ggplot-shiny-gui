# Documentation index

## 現在読むべき文書

- `../README.md` — 利用者向け概要、起動方法、必須ファイル、更新確認
- `../CHANGELOG.md` — バージョンごとの短い変更履歴
- `../V34_CHANGE_NOTES.md` — 現在版の詳細変更内容
- `../REFACTOR_CHECKPOINT.md` — 現在の重要な設計原則・リファクタリング境界
- `CURRENT_ARCHITECTURE_AND_PLAN.md` — アーキテクチャと今後の方針
- `FUNCTION_CATALOG.md` — 主要関数と責務の一覧
- `MAINTENANCE_RULES.md` — 保守ルール
- `TEST_CHECKLIST.md` — Windows/R環境での実機確認項目

## 過去の詳細履歴

- `CHANGE_HISTORY_ARCHIVE.md` — 旧バージョン固有のChange Notes / Trace / Validation / Static Audit Summary等を1本に統合した全文アーカイブ

過去の履歴Markdownは、内容を捨てずに元ファイルパス付きで上記Archiveへ統合しています。新しいリリースでは、現在版の詳細Change Notesだけをルートに残し、次のリリース時にArchiveへ移す運用を想定しています。

旧版の静的監査JSON/CSV・関数索引などの機械生成物は現行 `docs/` から除外しています。必要な場合は過去のReleaseまたはGit履歴を参照してください。

## ランタイム必須ファイル

以下はドキュメントではなく実行時依存ファイルです。削除しないでください。

- `../req.txt`
- `../anovakun_489.txt`
- `../anovakun_489_10.txt`
