 ggplot Shiny GUI

**R / Shiny と ggplot2 を使った、研究・論文・発表用グラフの作成補助のための、GUIアプリケーションです。**

[![Release](https://img.shields.io/badge/release-v4.1-blue)](https://github.com/kaziklubey/ggplot-shiny-gui/releases)
[![R](https://img.shields.io/badge/R-4.4.3%20tested-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-RStudio-blue)](https://shiny.posit.co/)

**Current release: v4.1 — 2026-09-30**

> 主な実機確認環境は **Windows / R 4.4.3** です。ほかのOS・Rバージョンでの完全な動作確認はまだ行っていません。

---

## Overview

ggplot Shiny GUI は、データを貼り付けて変数を割り当て、見た目を調整し、Figureを組み、必要に応じて統計解析まで行うためのGUIです。

Rコードを毎回書かなくても、Graphごとに設定を保持しながら、次のような流れをひとつのProjectとして扱えます。

```text
Data
  ↓
Reshape / Plot Filter
  ↓
Mapping
  ↓
Plot / Style / Error bar / Individual data
  ↓
Graph
  ↓
Figure layout / Legend / Inset / External assets
  ↓
PNG / PDF / SVG / editable PowerPoint
```

Graph編集とFigure編集は分離されています。Figureへ取り込んだGraphは **frozen snapshot** として保持されるため、元Graphを後から変更してもFigureが意図せず変化しません。

---

## Quick start

### 1. Release ZIPを入手

GitHubの [Releases](https://github.com/kaziklubey/ggplot-shiny-gui/releases) から最新版をダウンロードして展開します。

### 2. Rをインストール

[R](https://cran.r-project.org/) をインストールしてください。

v4.1 は **R 4.4.3 / Windows** を中心に実機確認しています。

### 3. `run.bat` を実行

Windowsでは、展開したフォルダの **`run.bat`** をダブルクリックします。

- `Rscript.exe` をPATHまたは標準的なRインストール先から自動探索します。
- `req.txt` に記載されたRパッケージが不足している場合は、CRANから自動インストールを試みます。
- 起動後、既定では `http://127.0.0.1:4006` をブラウザで開きます。

コマンドラインから起動する場合は、アプリのフォルダで次を実行します。

```bash
Rscript run.R
```

ポートを変更する場合は環境変数 `GGPLOT_GUI_PORT` を設定できます。

---

## Main features

### Graph editor

現在のGraph typeは次の4種類です。

| Graph | 主な機能 |
|---|---|
| **Line** | summary、Error bar、個体点、個体接続線、系列指定、接続しないX区間 |
| **Bar** | 横並び、積み上げ、100%積み上げ、数値Y、カテゴリ件数集計 |
| **Scatter** | Color / Shape、jitter、回帰直線、Facet |
| **Box** | stable slot、個体点、Color / Fill、Facet |

Mappingでは、Graph typeに応じて以下を組み合わせられます。

- X / Y
- Color / Fill
- Linetype
- Shape
- 横ずらし / 横並び要因
- 個体ID
- Facet

さらに、Category order、軸・目盛り、途中省略、ラベル、凡例、フォント、線幅、点サイズ、透明度などをGUIから調整できます。

### Data / Wide → Long

Graphごとにデータを保持します。

- Data textは `shinyAce` を使用
- Wide → Long Reshape
- Reshape後の列もMappingやPlot Filterで利用可能
- GraphごとにData / Reshape設定を保存
- Project保存・読込に対応

### Plot Filter — v4.1

v4.1 では、**元データを書き換えず、Plotに使う行だけを絞り込むFilter** を追加しました。

処理順は次のとおりです。

```text
Graph raw data
  ↓
Reshape
  ↓
Plot Filter
  ↓
active_plot_data
  ↓
Data View / Mapping / Summary / Plot
```

対応例:

- categorical: 使用する値を選択
- numeric: `>`, `>=`, `<`, `<=`, 範囲内, 範囲外
- numeric: 範囲指定と離散値選択の併用
- Date / DateTime: 比較・範囲指定
- ClockTime: 時間範囲と時刻選択
- `22:00 → 06:00` のような日跨ぎ時間範囲
- 欠損値を含める / 除外する
- 複数列の条件をANDで適用

Filter ON時はData Viewに **used / total** の行数を表示します。

Category order自体はFilterによって破壊されず、Filterを解除すると保存済みの順序へ戻ります。

---

## Bar graph

Barは次のlayoutを選択できます。

- **横並び**
- **積み上げ**
- **100%積み上げ**

値の作り方は次の2種類です。

- **数値Yを使用**
- **カテゴリを件数集計**

100%積み上げでは表示を **0–100%** または **0–1** から選択できます。

> 「カテゴリを件数集計」は各行を1件として数える機能です。個体ごとに割合を算出してから群平均する処理とは異なります。

---

## Individual data and error bars

Line / Bar / Boxでは、summaryだけでなく元の個体データも重ねて表示できます。

- 個体点
- IDによる対応点の接続
- point jitter / dodge
- SD / SEM / 95% CIなどのsummary表示
- 計算済みError bar列の利用
- Error barの色・線幅・横幅調整

Lineでは、除外したカテゴリ間を通常接続するほか、必要な箇所だけ明示的に線を切る「接続しないX区間」を設定できます。

---

## Figure editor

複数のGraphをひとつのFigureへ配置できます。

主な機能:

- GraphをFigureへ明示的にImport / Refresh
- 複数Panelの配置
- Auto / Fixed / Free layout
- panel基準の自動整列
- 行間・列間の調整
- 行高比・列幅比
- Graphごとのcrop / position調整
- Legendの表示位置変更・自由配置
- Inset
- Figure label
- 共通設定の適用
- Shared Style
- 外部画像 / SVGの追加
- 外部Graph / 凡例のみのAsset

### Frozen snapshot model

Figureは元Graphのlive mirrorではありません。

```text
Graph ── Import / Refresh ──> Figure snapshot
```

Import後にGraphを編集しても、Figureは自動更新されません。更新したいときだけ明示的に再読込します。

この設計により、完成済みFigureが別Graphの編集で意図せず変化することを防ぎます。

---

## Statistics

Statistics workspaceでは、Graphを見ながらAnalysisを作成できます。

対応している解析:

- **ANOVA**
  - 1要因
  - 2要因
  - 3要因
  - Greenhouse–Geisser / Huynh–Feldt
  - Holm / Shaffer 多重比較
- **t検定**
  - Welch two-sample t-test
  - paired t-test
- **Correlation**
  - Pearson
  - Spearman

AnalysisごとにData sourceを選べます。

1. **このGraphの元データ**
2. **現在のプロット用データ（Reshape + Plot Filter後）**
3. **別データを貼り付ける**

そのため、表示中のFilter済みGraphと同じ対象データで解析することも、元データを使って独立に解析することもできます。

Statistics側にはAnalysis専用のWide → Long Data preparationも用意されています。

---

## Export

GraphとFigureは次の形式へ出力できます。

- **PNG**
- **PDF**
- **SVG**
- **PowerPoint (`.pptx`)**

PowerPoint出力は `officer` + `rvg` を利用し、Graph / Figureを **編集可能なDrawingML** として出力する経路を持っています。

---

## Project files

作業状態は **`.ggplotpack`** として保存できます。

Projectには、GraphのData・Mapping・Style・Plot Filter、StatisticsのAnalysis state、Figure layout / snapshotなどが保存されます。

上部のProject操作から、次を利用できます。

- 開く
- 名前を付けて保存
- 上書き保存
- 閉じる
- 追加Projectウィンドウを開く

対応ブラウザでは、「保存先を記憶する」を使って上書き保存先をProject単位で保持できます。

---

## Required R packages

不足パッケージは起動時に `req.txt` を基準としてCRANから導入を試みます。

<details>
<summary>v4.1 dependencies</summary>

```text
shiny
shinyAce
ggplot2
dplyr
tidyr
shinyjs
scales
svglite
base64enc
colourpicker
jsonlite
ggbeeswarm
ggbreak
zip
ggh4x
rsvg
officer
rvg
xml2
```

</details>

---

## Update check

Windowsの `run.bat` から起動した場合、`check_update.ps1` がGitHub Releasesの最新版を確認します。

更新確認に失敗してもアプリの起動は継続します。

更新確認を無効にしたい場合は、環境変数を設定できます。

```text
GGPLOT_GUI_SKIP_UPDATE_CHECK=1
```

---

## Architecture

v4系では、Graph数が増えてもEditorをGraphごとに複製しない構造を採用しています。

### Graph

- Graph Editorは全Graph共通の **persistent single editor** 1個
- **GraphState Registry** がcanonical truth
- browser側は optimistic working copy
- Graph切替は `GraphState → persistent Editor` の transactional replay
- Data textはshinyAce native transport
- hidden per-Graph editor / warm DOM / hidden materializationは使用しない

### Figure

- Figureは **Figure-owned frozen snapshot**
- Graph → Figureは明示的Import / Refresh
- Graph編集はFigureへ自動伝播しない
- Figure専用のPlot Filter ownershipは持たない

### Statistics

- Analysis stateはStatistics側で独立保持
- Graph raw data / active plot data / custom dataを明示的に選択
- Plot MappingやStyleをStatisticsのdata ownershipへ混在させない

このownership分離は、Project save/loadやGraph切替時の再現性を維持し、古いUI stateが別Graphへ混入することを防ぐための中核設計です。

---

## Repository structure

```text
.
├─ R/
│  ├─ bootstrap/       # app config / package bootstrap / source manifest
│  ├─ data/            # Data, Reshape, Plot Filter
│  ├─ editor/          # persistent Graph Editor / replay
│  ├─ mapping/         # Mapping / Category order
│  ├─ plot/            # plot calculation / plot-specific runtime
│  ├─ state/           # GraphState / render state
│  ├─ figure/          # Figure state / renderer / layout
│  ├─ statistics/      # ANOVA / t-test / correlation
│  ├─ export/          # PNG / PDF / SVG / editable PPTX
│  ├─ server/          # Graph / Figure / Project server runtimes
│  ├─ style/           # Graph style / Shared Style
│  └─ ui/              # top-level UI shell
├─ www/                # browser runtime / CSS / Plot Filter JS
├─ tests/              # regression tests
├─ run.R
├─ run.bat
├─ server.R
├─ ui.R
└─ req.txt
```

開発時に最初に確認するファイル:

- `R/bootstrap/app_config.R` — version / non-reactive config
- `R/editor/graph_module.R` — Graph Editor module
- `R/editor/runtime/server_graph_state_replay_runtime.R` — Graph replay
- `R/state/runtime/graph_state_runtime.R` — canonical GraphState
- `R/data/graph_plot_filter.R` — Plot Filter semantics
- `R/plot/graph_plot_contract.R` — Plot type contract
- `R/server/figure/server_figure_source_snapshot_runtime.R` — Graph → Figure snapshot
- `R/server/project/server_project_io_runtime.R` — `.ggplotpack` save/load

---

## Validation status — v4.1

2026-09-30時点のrelease packagingで確認した内容:

- JavaScript regression: **49 / 49 PASS**
- JavaScript syntax check (`www` + `tests`): **52 / 52 PASS**
- ZIP CRC / fresh extraction: PASS
- Windows / R 4.4.3でPlot Filter UI、numeric値選択、主要Filter条件をsmoke test

Packaging環境にはRscriptがなかったため、その環境ではR regression suiteを実行していません。

詳細は [`RELEASE_NOTES_v4.1.md`](RELEASE_NOTES_v4.1.md) を参照してください。

---

## v4.1 highlights

v4.1では、v4.0.2のGraph / Figure architectureを維持したまま、主に次を追加・改善しました。

- Graph-owned Plot Filter
- Filter rule accordion UI
- numericの範囲 + 値選択
- ClockTimeの時間範囲 + 時刻選択
- 日跨ぎ時間Filter
- Data Viewのused / total表示
- Wide → Longなどの高速multi-select race対策
- Statisticsの「現在のプロット用データ」source
- PlotとStatisticsで使用中のデータ差を明示

詳細: [`RELEASE_NOTES_v4.1.md`](RELEASE_NOTES_v4.1.md)

---

## Known notes

- 主な実機検証環境はWindowsです。
- 一部Windows fontではPostScript font database関連のwarningが出る場合があります。
- 現在のPlot typeは **Line / Bar / Scatter / Box** です。
- Count categoriesは全行countであり、個体ごとの割合を平均する解析ではありません。

---

## Bug reports

不具合報告では、可能であれば次の情報を添えてください。

- ggplot Shiny GUIのversion
- Rのversion
- OS
- 再現手順
- 使用したGraph type / Data形式
- コンソールログ
- 問題がProject save/loadに関係する場合は、その操作順

GitHub Issues: <https://github.com/kaziklubey/ggplot-shiny-gui/issues>

---

## Release notes

- [v4.1 Release Notes](RELEASE_NOTES_v4.1.md)
- [GitHub Releases](https://github.com/kaziklubey/ggplot-shiny-gui/releases)
