# spec/review/ — spec 敵対的レビューの記録

Phase 2 の spec ドラフトに対する、`spec-reviewer` サブエージェントのレビュー指摘を残す。
**「1発で100点は取れない」前提**で、レンズ別 × 複数ラウンドの**レビューラリー**を記録する。

## 命名規則

```
<レンズ>_<連番>.md
```

- **レンズ**: `completeness`（完全性）/ `fidelity`（コード忠実性）/ `modernization`（モダン化整合）
- **連番**: ラウンド番号（`01`, `02`, …）。ドラフト改訂ごとに再レビュー＝連番が増える。

例: `completeness_01.md` / `fidelity_01.md` / `modernization_01.md` / `completeness_02.md` …

## フロー

1. くろ（オーケストレータ）が spec ドラフト作成（`spec/behavior/*.md`・`spec/backlog-map.md` 等）
2. `spec-reviewer` を3レンズで並列起動 → 各自ここに `<レンズ>_<連番>.md` を出力
3. くろが指摘を spec に反映
4. 残指摘があれば連番を上げて再レビュー（ラリー）→ 収束したら PO へ（Feature→Story→AC）
