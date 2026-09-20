# Release notes — v3.73.2.39

## 概要

v3.73.2.39は、persistent single Graph EditorでのGraph切替時に発生していたMapping汚染を修正し、凡例設定を整理した安定化リリースです。

公開版の識別は **`v3.73.2.39`** に統一します。開発途中で使っていたPhase番号や内部suffixはRelease名・runtime versionには使用しません。

## Mapping replay修正

以前は、異なる列構成のGraphへ切り替えた後に既存Graphへ戻ると、Color / Shape / IDなどのselected valueが前GraphのselectInput choicesに対して一時的に無効となり、空値がlive editとしてcanonical GraphStateへ保存される場合がありました。

v3.73.2.39ではGraph replayをMapping transactionとして扱います。

```text
target GraphState
  -> raw data / reshape / transformed dataをtarget基準で構築
  -> Mapping choices / selected valuesをtarget基準で確定
  -> persistent Editorへreplay
  -> Mapping bindingをbrowserから送出
  -> completion ACK
  -> canonical acceptance
  -> final render
```

通常choices writerはtransaction中にtarget stateを上書きしません。保存候補にはgenerationとreplay状態を持たせ、別generationやreplay中に取得された古い候補はcanonical stateへcommitしません。

retry、semantic reconcile、hidden Graph materialization、per-Graph Editorは追加していません。

## 凡例設定

グループguideと個体点guideを独立して扱えるよう整理しました。

- グループ凡例 表示ON/OFF
- 個体点凡例 表示ON/OFF
- 同じ条件を表すグループ / 個体点guideの統合ON/OFF
- グループ凡例タイトル 表示ON/OFF・任意文字列
- 個体点凡例タイトル 表示ON/OFF・任意文字列
- タイトル表示は両方ともデフォルトOFF

統合ONでは1 guideとして扱い、グループ側タイトルを共通タイトルとして使用します。統合OFFでは2 guidesとして扱い、それぞれ独立したタイトルを使用します。タイトル文字列の変更そのものは統合/分離条件ではありません。

これらの設定はGraphState、Project保存、style persistence、Settings Manager、DIRECT-STATE Figure/Exportへ接続されています。

## 実機確認

Windows / R 4.4.3環境で以下を確認済みです。

- 既存GraphでColor=`group_label`、ID=`id`を使用
- 列構成の異なる新規Graphへ切替
- 元Graphへ複数回戻ってもColor / IDを保持
- 旧症状の `Column id not found` とMapping空値commitが再発しないことを確認
- グループ凡例 / 個体点凡例の表示ON/OFF
- guide統合ON/OFFの往復
- グループ凡例タイトルの表示と文字列変更
- 個体点凡例タイトルの表示と文字列変更
- Project保存 → 再起動 / 再読込後も設定を保持

## 回帰テスト

```text
Rscript tests/regression_mapping_legend.R
node tests/regression_mapping_transport.cjs
```

加えて、R source parse、Shiny testServer、ggplot guide条件、JavaScript syntax check、Project / Graph switchingの実ブラウザ確認を実施しています。

## Architecture上の維持条件

- Graph authorityはcanonical `GraphState`
- 通常Graph Editorは1個だけ
- dormant Graphはstate-only
- Figure Main / InsetはFigure-owned snapshot
- Figure / Export / Settings batchのためにhidden Graph Editorを作らない
- Graphの旧restore/remount/retry/reconcile runtimeを復活させない
- Statistics固有のrestore barrierはGraph replayとは分離したまま維持
