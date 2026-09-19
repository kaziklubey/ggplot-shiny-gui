# ggplot-shiny-gui

R / Shiny を使った、ggplot2ベースのグラフ作成・Figure編集GUIです。

コードを書かずに、複数Graphの作成・設定変更・比較、Figureへの配置、統計解析、Project保存/読込などを行えるようにしています。

## 主な機能

- ggplot2によるグラフ作成
- 複数Graphの管理
- GraphごとのData / Mapping / Appearance設定
- 軸、凡例、フォント、サイズ、色などの調整
- Graph Settings Managerによる複数Graphの比較・一括編集
- Graphのみ / Figureのみ / Graph + Figureへの設定反映
- 複数Graphを配置したFigure作成
- Figure内でのサイズ・配置・凡例調整
- 統計解析
- `.ggplotpack` によるProject保存・読込
- 起動時のGitHub Release最新版確認

## 動作環境

- Windows
- R
- 必要なRパッケージは `req.txt` に記載

Rは以下から入手できます。

https://cran.r-project.org/

## 起動方法

1. GitHubの **Releases** から最新版ZIPをダウンロード
2. ZIPを任意のフォルダへ展開
3. `run.bat` をダブルクリック

`run.bat` が `Rscript.exe` を探し、Shinyアプリを起動します。

## アップデート確認

`run.bat` 起動時に、以下のGitHub Releasesの最新版を確認します。

https://github.com/kaziklubey/ggplot-shiny-gui

新しいバージョンがある場合は、

- `U` を押す → GitHubのReleaseページを開く
- Enter → 現在のバージョンをそのまま起動

を選択できます。

ネット接続がない場合、GitHub APIに接続できない場合、Releaseがまだ無い場合でも、アップデート確認をスキップして通常起動します。

更新確認を無効化したい場合は、起動前に環境変数 `GGPLOT_GUI_SKIP_UPDATE_CHECK=1` を設定します。

## 必須ランタイムファイル

以下はアプリの動作に必要なので削除しないでください。

```text
anovakun_489.txt
anovakun_489_10.txt
req.txt
run.R
run.bat
```

特に `anovakun_489.txt` と `anovakun_489_10.txt` は統計解析で使用する必須ファイルです。

## Project保存

作成したGraphやFigureの状態は `.ggplotpack` として保存できます。

保存したProjectを読み込むことで、Graph設定やFigure配置を後から編集できます。

## GraphとFigureの関係

GraphとFigureは別の状態として管理します。

```text
Graphを変更
↓
Figureは自動では変更しない
```

Figureへ反映したい場合は明示的に更新します。Figure / Exportは保存済みGraphStateからserver-sideで直接描画し、dormant Graphのためにhidden Graph Editorを生成しません。

Graph Settings Managerでは、`Graphだけ` / `Figureだけ` / `Graph + Figure` を選んで設定を反映できます。Figure側だけで最終調整しても、元Graphを変更せずに済みます。

## GitHub上の運用

- `main` ブランチ: 現在のソースコード
- `Releases`: 配布用ZIP、SHA256、必要に応じてpatch
- 過去Release: そのまま保存し、過去版を取得できるようにする

## ドキュメント

- `CHANGELOG.md` — 各バージョンの短い変更履歴
- `V34_CHANGE_NOTES.md` — 現在版の詳細変更内容
- `REFACTOR_CHECKPOINT.md` — 開発上の重要な設計原則
- `docs/README.md` — 開発者向けドキュメント索引
- `docs/CHANGE_HISTORY_ARCHIVE.md` — v33以前の詳細変更・検証履歴を統合したアーカイブ

過去バージョン固有の `Vxx_CHANGE_NOTES.md`、`TRACE`、`VALIDATION`、`STATIC_AUDIT_SUMMARY` は、ファイル数を増やさないため `docs/CHANGE_HISTORY_ARCHIVE.md` に全文保存しています。

旧バージョンで生成していた静的監査用のJSON/CSVは現行配布物には含めていません。必要な場合は過去のReleaseまたはGit履歴から参照できます。

## Repository

https://github.com/kaziklubey/ggplot-shiny-gui
