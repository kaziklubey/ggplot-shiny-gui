# ggplot-shiny-gui

**Current release: v3.73.2.39**

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

## 必須ランタイムファイル

以下は削除しないでください。

```text
anovakun_489.txt
anovakun_489_10.txt
req.txt
run.R
run.bat
```

特に `anovakun_489.txt` と `anovakun_489_10.txt` は統計解析で使用します。

## Project保存

Graph / Figure / Statisticsの編集状態は `.ggplotpack` として保存できます。保存したProjectを読み込むことで、後から編集を再開できます。

v3.73.2.39では、異なる列構成のGraphを切り替えた後でも、既存GraphのColor / Shape / IDなどのMappingが空値へ巻き戻らないよう、Mapping replayを1つのtransactionとして処理します。Project保存→再読込後のMapping保持もWindows実機で確認済みです。

## 現行アーキテクチャ

通常Graphは **1個のpersistent Graph Editor** を共有します。Graph切替では、保存済みのcanonical `GraphState`から対象Graph用のData / Mapping choices / selected valuesを組み立て、同じEditorへreplayします。

```text
canonical GraphState
  -> target Graph用Mapping plan
  -> persistent Editorへvalue replay
  -> browser completion barrier
  -> canonical acceptance
  -> final render
```

Figure / Export / dormant Graphへの一括設定はGraphごとのhidden Editorを生成せず、canonical stateまたはFigure-owned stateからserver-sideで直接処理します。

旧来のhidden per-Graph module、Graph materialization、remount、semantic reconcile、retryによるGraph復旧経路は現行runtimeにはありません。

## GraphとFigureの関係

GraphとFigureは別の状態として管理します。

```text
Graphを変更
↓
既存Figureは自動では変更しない
```

Figureへ反映したい場合は明示的に更新します。Figure / Exportは保存済みGraphStateからserver-sideで直接描画し、dormant Graphのためにhidden Graph Editorを生成しません。

Graph Settings Managerでは `Graphだけ` / `Figureだけ` / `Graph + Figure` を選択できます。Figure側だけで最終調整しても元Graphは変更されません。


