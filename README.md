# ggplot-shiny-gui

R / Shiny を使った、ggplot2ベースのグラフ作成・Figure編集GUIです。

コードを書かずに、複数Graphの作成・設定変更・比較・Figureへの配置・統計解析などを行えるようにしています。

## 主な機能

- ggplot2によるグラフ作成
- 複数Graphの管理
- Graphごとのデータ・Mapping・Appearance設定
- 軸、凡例、フォント、サイズ、色などの調整
- Graph Settings Managerによる複数Graphの比較・一括編集
- Graphのみ / Figureのみ / Graph + Figureへの設定反映
- 複数Graphを配置したFigure作成
- Figure内でのサイズ・配置・凡例調整
- 統計解析
- `.ggplotpack` によるプロジェクト保存・読込
- 起動時のGitHub最新版確認

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

`run.bat` が `Rscript.exe` を自動で探し、Shinyアプリを起動します。

## アップデート確認

`run.bat` 起動時に、GitHub Releasesの最新版を確認します。

新しいバージョンがある場合は、

- `U` を押す → GitHubのReleaseページを開く
- Enter → 現在のバージョンをそのまま起動

を選択できます。

ネット接続がない場合やGitHubへ接続できない場合でも、
アップデート確認をスキップして通常通り起動します。

アップデート確認を無効化したい場合は、

```bat
set GGPLOT_GUI_SKIP_UPDATE_CHECK=1
````

を使用します。


## Project保存

作成したGraphやFigureの状態は、

```text
*.ggplotpack
```

として保存できます。

保存したProjectを読み込むことで、
Graph設定やFigure配置を後から編集できます。


## GitHub上の構成

`main` ブランチには最新版のソースコードを置きます。

完成版ZIPは **Releases** に置きます。

過去のバージョンもReleasesから取得できます。

## 変更履歴

詳しい変更内容は、

```text
CHANGELOG.md
```

および各バージョンの

```text
Vxx_CHANGE_NOTES.md
```

を参照してください。

## Repository

[https://github.com/kaziklubey/ggplot-shiny-gui](https://github.com/kaziklubey/ggplot-shiny-gui)



