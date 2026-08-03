# reports/

migration パイプラインの **before/after まとめ（curated・版管理する）**。記事・実証用。

- **Phase 1（before）**: `legacy-jpetstore` の脆弱性棚卸しサマリ
- **Phase 4（after）**: リビルド版で脆弱性が消えたことの実証サマリ

## `reports/` と `security/` の役割分担

| | 置き場 | git | 中身 |
|---|---|---|---|
| **生実行成果物** | `security/<YYYYMMDD>_<nn>/` | **ignore** | SEC の Find-and-Fix の raw（discovery / verification / poc / summary.html）。`file:line`・PoC・悪用手順を含む。**legacy でも modern（jpetstore-backend/frontend）でも、SEC が回すたびの生ログはここ** |
| **before/after まとめ** | `reports/` | **track** | 上記から危険な詳細を落とした、migration の before/after 証跡（記事用） |

⚠️ `reports/` も念のため public 公開時は内容を要レビュー。
