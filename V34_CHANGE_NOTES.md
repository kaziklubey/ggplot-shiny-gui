# v3.73.2.36-phase2-direct-state1

## Phase 2 — hidden materialization removal

- Figure / Export / Shared Styleのsource生成をcanonical `GraphState` direct-state経路へ統一。
- dormant Graphのためのhidden `graphUI()` / `graphServer()` materializerと、そのqueue / mount ACK / browser drain / revision leaseを削除。
- Figure Shared StyleはFigure-owned stateからdirect snapshotを再生成し、Figure Editor sequential queueを使用しない。
- 通常Graphのpersistent single editor、Figure snapshot independence、Phase 1.2の`figure-replay-ready` render ownershipは維持。

# v3.73.2.34-github-clean1

## GitHub / Release tree cleanup

- GitHub `main` と配布ZIPを同じクリーンなソースツリーに揃えるため、旧版の機械生成監査ファイルを `docs/` から除外しました。
- 除外対象は、過去の `STATIC_AUDIT.json`、`UNRESOLVED_INTERNAL_CALLS.csv`、`MODULE_API_USAGE.csv`、`DEFERRED_ORPHAN_CANDIDATES.csv`、`FUNCTION_INDEX.csv`、`SERVER_RUNTIME_SPLIT_MANIFEST.json`、`refactor_audit.json` など計36ファイルです。
- 現行 `docs/` は次の6ファイルだけです。
  - `README.md`
  - `CHANGE_HISTORY_ARCHIVE.md`
  - `CURRENT_ARCHITECTURE_AND_PLAN.md`
  - `FUNCTION_CATALOG.md`
  - `MAINTENANCE_RULES.md`
  - `TEST_CHECKLIST.md`
- `V33_CHANGE_NOTES.md` は全文を `docs/CHANGE_HISTORY_ARCHIVE.md` に移し、ルートには現在版の `V34_CHANGE_NOTES.md` だけを残しました。
- 旧監査JSON/CSVは過去のReleaseまたはGit履歴から参照できます。
- 必須ランタイムファイル `anovakun_489.txt` / `anovakun_489_10.txt` は保持しています。
- R/ShinyのGraph / Figure / Statistics / Project / update-check 実行ロジックには変更していません。
