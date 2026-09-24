# ggplot-shiny-gui

**Current release: v4.0**

R / Shiny と ggplot2 を使ったグラフ作成・Figure編集GUIです。コードを書かずに、複数Graphの作成・設定変更・比較、Figureへの配置、統計解析、Project保存/読込などを行えます。

## 主な機能

- ggplot2によるグラフ作成
- 複数Graphの管理と切替
- GraphごとのData / Mapping / Appearance設定
- 軸、凡例、フォント、サイズ、色などの調整
- グループ凡例 / 個体点凡例の独立表示、統合/分離、タイトル設定
- Graph Settings Managerによる複数Graphの比較・一括編集
- Graphのみ / Figureのみ / Graph + Figureへの設定反映
- 複数Graphを配置したFigure作成
- Figure内でのサイズ・配置・凡例・Inset調整
- 統計解析
- `.ggplotpack` によるProject保存・読込
- 起動時のGitHub Release最新版確認

## 動作環境

- Windows
- R
- 必要なRパッケージは `req.txt` に記載

R: https://cran.r-project.org/

## 起動方法

1. GitHubの **Releases** から最新版ZIPをダウンロード
2. ZIPを任意のフォルダへ展開
3. `run.bat` をダブルクリック

`run.bat` が `Rscript.exe` を探してShinyアプリを起動します。

## アップデート確認

`run.bat` 起動時に次のGitHub Releasesを確認します。

https://github.com/kaziklubey/ggplot-shiny-gui

新しいバージョンがある場合は、`U`でReleaseページを開くか、Enterで現在のバージョンを起動できます。ネット接続がない場合やGitHub APIへ接続できない場合も、確認をスキップして通常起動します。

更新確認を無効化する場合は、起動前に環境変数 `GGPLOT_GUI_SKIP_UPDATE_CHECK=1` を設定します。


Graph Settings Managerでは `Graphだけ` / `Figureだけ` / `Graph + Figure` を選択できます。Figure側だけで最終調整しても元Graphは変更されません。


