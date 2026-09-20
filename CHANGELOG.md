# Changelog

## v3.73.2.39

- Graph切替時のMapping replayをtransaction化。異なる列構成のGraphを往復した際に既存GraphのColor / Shape / ID等が空値へ巻き戻る問題を修正。
- replay中のData / reshape / Mapping choices / selected valueをtarget GraphState基準に固定。
- browser completion前にMapping binding値を送出し、古いgeneration / replay中の保存候補をcanonical commitから除外。
- グループ凡例と個体点凡例の表示ON/OFFを独立化。
- 同じ条件を表すグループguideと個体点guideの統合/分離を明示設定化。
- グループ凡例タイトルと個体点凡例タイトルを独立化。両タイトルともデフォルトOFF。
- Project保存→再読込、Graph往復、凡例各設定をWindows実機で確認。
- 公開version表記を `v3.73.2.39` に統一し、Phase番号・内部suffixを公開名から廃止。

## v3.73.2.38

- Mapping choicesをtarget Graph基準でreplayする最初の修正と、凡例表示/統合設定を導入。
- 実機検証でREADY後の通常observerがColor / IDを再度空値へ変更できる経路が残っていることを確認。
- Mapping修正はv3.73.2.39で置き換え。v3.73.2.38は使用非推奨。

## v3.73.2.37

- callerを失ったGraph structural restore / remount / retry / semantic reconcile runtimeを削除。
- persistent single Editorのcanonical GraphState value replayへ一本化。
- Statistics固有のrestore barrierをGraph lifecycleから分離。
- current architecture / function catalog / test checklistを整理。

## v3.73.2.36

- Figure / Export / Shared Styleからhidden per-Graph materializationを撤去。
- dormant Graphをcanonical GraphStateからDIRECT-STATEで処理する構造へ移行。
- Inset初回source snapshotをDIRECT-STATE化。
- Figure ViewerとExportで同じfrozen Inset SVGを使用するWYSIWYG挙動へ統一。

## v3.73.2.35

- Figure Editor replayのrender releaseをbrowser completion後へ一本化。
- owner-followとselected Figure Editor同期を安定化。
- Inset persistence、preview validation、stale Figure SVG対策、Y-axis guardを追加。

## v3.73.2.34

- GitHub / Release向けに配布ツリーとdocumentationを整理。
- 過去の詳細変更・検証資料を `docs/CHANGE_HISTORY_ARCHIVE.md` へ統合。

より古い開発履歴は `docs/CHANGE_HISTORY_ARCHIVE.md`、Git history、過去Releasesを参照してください。
