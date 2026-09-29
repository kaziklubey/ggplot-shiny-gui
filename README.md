# ggplot Shiny GUI v4.0.2

R/Shiny ベースの ggplot 作図・Figure 編集 GUI です。Windows での対話的な作図、複数 Graph の管理、Figure レイアウト、Statistics、画像・Office 出力を1つの Project として扱います。

このファイルは **README / Release Notes / Validation / 開発引継ぎ** を1つに統合した v4.0.2 の基準ドキュメントです。配布ZIP内の開発用 Markdown はこの `README.md` に集約しています。

## 起動

Windows ではフォルダ直下の `run.bat` を実行してください。

- R 4.4 系で開発・実機確認しています。
- 必要パッケージは `req.txt` を基準に確認・導入します。
- 既定ポートは `4006` です。必要なら環境変数 `GGPLOT_GUI_PORT` で変更できます。
- runtime version owner は `R/bootstrap/app_config.R` の `APP_VERSION` です。
- `server.R` の起動ログは `app_version()` を読むため、通常は `server.R` 側のversion文字列を直接変更しません。

Current release: **v4.0.2**

---

## Release Notes — v4.0.2

v4.0.2 は、v4.0.1 で確立した persistent single Graph Editor / GraphState canonical / Figure frozen ownership を維持しながら、Bar の積み上げ・カテゴリ件数・割合表示を正式機能として追加したリリースです。

### Bar layout

Bar は次の表示方法に対応します。

- **横並び**: 従来のBar表示。
- **積み上げ**: Color / Fill の系列を同じBar内へ積み上げ。
- **100%積み上げ**: 各Bar内を割合へ正規化。

`Position` mapping は従来どおりX内の追加横並び要因です。積み上げ時は `X × Position` ごとに独立したBarを作り、その内部を Color / Fill で積み上げます。Facetとも併用できます。

### Bar の値ソース

UI表示は日本語へ統一しています。

- **棒グラフの値**
  - **数値Yを使用** (`numeric_y`)
  - **カテゴリを件数集計** (`count`)

内部state value (`numeric_y`, `count`) は保存互換性のため変更しません。

#### 数値Yを使用

従来の数値Yを使用します。平均等のsummary semanticsを維持し、積み上げ時はsummary後のsegment値を積み上げます。`値（集計しない）` で同一segmentに複数行がある場合はYを合計します。

積み上げ中は Error bar / 個体点 / 個体接続線などを描画しませんが、設定値は休眠保持し、横並びへ戻すと復帰します。

#### カテゴリを件数集計

Y列を使わず、各行を1件として `X × Color/Fill × Position × Facet` 単位でカウントします。

100%積み上げでは `X × Position × Facet` ごとに Color / Fill カテゴリの件数を100%へ正規化します。

これは **全行を直接countした割合**です。以下は未実装です。

- 各個体で割合を計算する処理
- 個体割合を群で平均する処理
- そのSEM / CI表示

これらは統計的に別処理なので、今後追加する場合も Count categories と混ぜず、別のsummary semanticsとして設計します。

### 100%積み上げのY軸表示

同じ0〜1の割合geometryを、2種類の軸表現から選択できます。

- **パーセント**: 0%〜100%
- **比率**: 0〜1.0

表示切替でsegmentの高さや割合計算は変わりません。通常Bar用のY軸範囲・tick・axis break設定は100%積み上げ中は休眠保持し、別layoutへ戻すと再利用されます。旧Projectで設定が存在しない場合はパーセント表示をdefaultにします。

### Category order

積み上げBarでも既存Category orderを利用し、Color / Fillカテゴリ順、stack順、legend順を変更できます。5カテゴリーの積み上げと並べ替えはユーザー実機で確認済みです。

### Plot contract cleanup

現行Plot typeは **Line / Bar / Scatter / Box** です。旧 `violin` 別名互換はproductionから削除済みで、Violin追加予定はありません。

`graph_plot_type_specs()` には plot type ID、primary aesthetic、position semantics、stable-slot support、snapshot acceptance など、意味が一致する小さな判定だけを集約しています。Line / Scatter固有の描画やgeom branchは無理に一般化しません。

### Data欄 Project restore 修正

v4.0.2実機テストで、Project保存→読込後にGraphは正常に復元する一方、左側の Data欄（shinyAce）だけが空になる表示不具合が見つかりました。

保存された `GraphState$data_text` 自体は正常で、問題は GraphState → persistent Editor replay 時の Ace hydrate漏れでした。

修正版では `data_text` を generic browser-direct scalar payload に戻さず、canonical `GraphState$data_text` を `shinyAce::updateAceEditor()` で明示hydrateします。

- replay generation確認後にhydrate
- 空Dataは `""` で明示clear
- 同一Graphの通常Data commitでは不要なechoをしない
- canonical再commitや不要なrender revisionを起こさない
- large Data textは引き続き shinyAce native transport が所有

この修正は `v4.0.2-data-text-hydrate1` で導入され、v4.0.2最終配布物へ統合する前提です。

---

## State ownership / Architecture

### Graph Editor

- Full Graph Editor は全Graph共通の **persistent single Editor 1個**。
- Graphごとの hidden editor/module、warm DOM、hidden materializationを復活させない。
- Graph切替は GraphState → persistent Editor の transactional replay。
- Browserは optimistic working copy。**GraphState Registry がcanonical truth**。
- browser-direct replay / path-local optimistic rebase を維持する。

### Data

- `data_text` は canonical GraphState が所有。
- 大きなData textをgeneric browser patch / scalar replayへ載せない。
- Data編集は shinyAce native transport → canonical commit。
- Project load / Graph switch時の表示復元も shinyAce native hydrate。
- Data schema変更時のMapping reconcileはcanonical側で行う。

### Figure

- FigureはGraphのlive mirrorではなく **Figure-owned frozen snapshot**。
- Graph編集後もFigureは自動追従しない。
- Graph→Figureは明示 Import / Refresh。
- Figure→Graph Applyは Mapping / Plot / Labels / Style / appearance / size のeditable subsetだけ。
- Figure→Graphで新しいGraph側の Data / reshape / Statistics を上書きしない。
- Panel assignmentはlayout操作であり、自動importではない。
- FigureStateはpanel removal後も保持する。
- Inset snapshotはowner Figure Graph単位で独立保持する。

### Shared Style

- Library → Graph と Graph → Library はdirectional flow。
- Graph-local binding stateを維持する。
- FigureはfrozenなのでShared Style変更へ自動追従させない。

### 実装上の禁止事項

- hidden per-Graph editor
- warm DOM復活
- dormant Graph materialization
- polling
- sleep / timeout頼み
- warning suppressionで問題を隠す
- browser DOM / Shiny input mirrorをcanonical truthにする
- 大規模既存関数への継ぎ足し。責務が増える場合はfocused helper/runtimeへ分離する。

---

## v4.0.1から継承する主要機能

- Data / Mapping canonicalization
- browser-direct replay
- path-local optimistic rebase
- Scatter jitter
- Category order
- Bar/Box stable slot
- Line Series mode
- Shared Style directional flow / binding isolation
- Figure explicit Graph Sources import / refresh
- Figure Common Settings
- Figure auto panel alignment
- Figure Preview horizontal scroll rail
- continuous numeric policy
- fractional base font
- draw-time error boundary
- JSON safe-tree serialization cleanup

---

## Validation

### v4.0.2本体

- JavaScript regression: **47 / 47 PASS**
- JavaScript syntax: **49 / 49 PASS**
- R structural scan: **129 files / 0 errors**
- FILE_LAYOUT: **95 / 95**
- literal source refs: **86 / 0 missing**
- patch recreation: PASS
- ZIP CRC: PASS
- fresh extraction: PASS

### Data-text hydrate修正

- JavaScript regression: **48 / 48 PASS**
- JavaScript syntax: **50 / 50 PASS**
- FILE_LAYOUT: **95 / 95**
- production source refs: **116 / 0 missing**
- patch recreation: PASS
- ZIP CRC: PASS
- fresh extraction: PASS

このビルド環境にはR/Rscriptがないため、R runtime regressionはここでは実行していません。Windows / R 4.4.3 のユーザー実機で、v4.0.2本体の stacked / count / category order / save-load は確認されています。

---

## 実機確認済み / 次の確認

確認済み:

- Line / Bar / Scatter / Box 切替
- stacked Bar
- 100% stacked
- Count categories
- 5カテゴリー積み上げ
- Category order変更
- Project save / loadでGraph自体が復元
- 100%表示のパーセント / 比率 state変更と再描画

次に確認する項目:

1. Dataを貼る。
2. Project保存。
3. Projectを閉じる、またはアプリを再起動。
4. Project読込。
5. Data欄へ元テキストが復元されること。
6. Graph A → B → Aで各Graph固有Dataへ切り替わること。
7. Dataが空のGraphでは前GraphのDataが残らず空になること。
8. 可能なら高速A→B→A切替で古いhydrateが刺さらないこと。

---

## 既知の保留事項

### Font warning

一部Windows fontで `font family '...' not found in PostScript font database` warningが出る場合があります。Figure Preview clippingとは別問題です。warning suppressionは行わず、font metric / backend cleanup候補として保留します。

### Update checker metadata

v4.0.2実機ログで `Current: v4.0.2 / Latest: v4.0.1` と表示されたため、公開時はremote/latest version metadataの更新が必要です。

### 将来のBar候補

- 個体ごとのカテゴリ割合 → 群平均
- そのSEM / CI表示
- stack segment内の件数 / 割合label

現在の Count categories は **全行count** という意味を明確に維持します。

---

## 開発引継ぎ

### 現在の基準

この配布物は以下を統合した v4.0.2 最終候補です。

- v4.0.2 Bar stacked / count / proportion display
- Data text native hydrate fix
- Bar value/source UIの日本語化

### 最初に読むファイル

- `R/bootstrap/app_config.R` — APP_VERSION
- `server.R` — startup / top-level server orchestration
- `R/editor/runtime/server_graph_state_replay_runtime.R` — GraphState replay / Data text native hydrate
- `R/editor/graph_module.R` — persistent Graph Editor module
- `R/editor/ui/graph_ui_module.R` — Graph Editor UI
- `R/plot/graph_plot_contract.R` — Plot type contract
- `R/plot/calculation/graph_plot_data_calculation.R` — Bar count data preparation
- `R/plot/calculation/graph_plot_calculation.R` — geom / stacked rendering
- `R/state/runtime/graph_state_runtime.R` — canonical GraphState runtime
- `R/state/graph_render_state.R` — active render-state collapse
- `R/server/figure/server_figure_source_snapshot_runtime.R` — Graph→Figure snapshot
- `R/server/figure/server_figure_workspace_runtime.R` — Figure workspace / explicit refresh
- `R/server/project/server_project_io_runtime.R` — Project save/load

### バージョン表記

`APP_VERSION <- "v4.0.2"` は `R/bootstrap/app_config.R` が唯一のruntime ownerです。

`server start v4.0.2` は `server.R` の `diag_log("SESSION", paste0("server start ", app_version()))` から出力されます。

---

## Documentation policy

配布ZIPを簡潔に保つため、以前の多数の `VALIDATION-*`, `IMPLEMENTATION_NOTES-*`, `CLEANUP_REPORT-*`, `UI_CHANGELOG-*`, `docs/history/*.md` はこのREADMEへ要点を統合しました。

詳細な履歴が必要な場合はGit履歴 / 過去の開発成果物を参照し、配布ZIP内に古いMarkdownを再び増やさない方針とします。
