---
name: discord-operations
description: JPetStore Migration スクラムチームのDiscordサーバーへの投稿・参照手順。SM・DEV・PO・reviewerがDiscordに投稿する、スレッドを作成する、既存スレッドに返信する、チャンネルの最新メッセージを読む、といった操作が必要なときは必ずこのスキルを参照すること。チャンネルタイプ（TextかForumか）の判定と使用ツールの選択を誤ると投稿が失敗するため、このスキルを読まずに操作してはならない。
---

# Discord Operations

JPetStore Migration スクラムチームのDiscordサーバーに対する投稿・参照操作の手順。

## チャンネル一覧とタイプ

| チャンネル名        | ID                    | タイプ | 用途             |
| ------------------- | --------------------- | ------ | ---------------- |
| `#skills-changelog` | `1489422432635850863` | Text   | Skills更新記録   |
| `#10-planning`      | `1489422519416131644` | Forum  | Planning完了報告 |
| `#20-sprint`        | `1489422592539623614` | Forum  | 作業スレッド管理 |
| `#30-sprint-review` | `1489422648449695824` | Forum  | Sprint Review    |
| `#40-retrospective` | `1489422706435821701` | Forum  | Retrospective    |

Guild ID: `1489421564439797780`

---

## ツールの使い分け（最重要）

チャンネルタイプによって使用するツールが異なる。**間違えると投稿が失敗する。**

| 操作                        | Textチャンネル                                 | Forumチャンネル             |
| --------------------------- | ---------------------------------------------- | --------------------------- |
| 新規投稿 / 新規スレッド作成 | `discord_send`                                 | `discord_create_forum_post` |
| 既存スレッドへの返信        | `discord_send`（channel_idにスレッドIDを指定） | `discord_reply_to_forum`    |
| 最新メッセージを読む        | `discord_get_messages`                         | スレッドIDを指定して取得    |

---

## 操作パターン別の手順

### 1. Textチャンネルに投稿する

```
ツール: discord_send
パラメータ:
  channel_id: [チャンネルID]
  content: "[投稿内容]"
```

### 2. Forumチャンネルに新規スレッドを作成して投稿する

```
ツール: discord_create_forum_post
パラメータ:
  channel_id: [ForumチャンネルのID]
  title: "[スレッドタイトル]"
  content: "[投稿内容]"
```

戻り値のスレッドIDを必ず保持する（以降の返信で使用する）。

### 3. Forumチャンネルの既存スレッドに返信する

```
ツール: discord_reply_to_forum
パラメータ:
  thread_id: [スレッドID]
  content: "[返信内容]"
```

### 4. チャンネル・スレッドの最新メッセージを読む

投稿前に必ず最新メッセージを確認すること。

```
ツール: discord_get_messages
パラメータ:
  channel_id: [チャンネルIDまたはスレッドID]
  limit: 10  # 直近10件が目安
```

---

## 投稿ルール

- 投稿前に対象チャンネル・スレッドの最新メッセージを読む
- 投稿の先頭に役割プレフィックスをつける：
  - SMの投稿 → `[SM]`
  - DEVの投稿 → `[DEV]`
  - POの投稿 → `[PO]`
  - convention-reviewerの投稿 → `[convention-reviewer]`
  - security-reviewerの投稿 → `[security-reviewer]`
  - performance-reviewerの投稿 → `[performance-reviewer]`
- **Forumスレッドのタイトルは先頭に `[JPS]` を付ける**（JPetStore Migration プロジェクトのスレッドである印）。
  例: `[JPS] Sprint 1 作業スレッド` / `[JPS] Planning完了報告 Sprint 1`。
  ⚠️ これらの Discord チャンネルは **HwHub チームと共用**しており、両プロジェクトのスレッドが混在する。
  スレッド作成時は必ず `[JPS]` を付け、既存スレッドを検索するときも `[JPS]` プレフィックスで判別すること。

---

## スレッドIDの取得方法

SMがスプリント作業スレッドを作成した際は、`discord_create_forum_post` の戻り値からスレッドIDを取得する。
DEV・各reviewerがそのスレッドに返信する場合、SMからSendMessageでスレッドIDを受け取るか、`#20-sprint` のスレッド一覧から該当スプリントのスレッドを検索して取得する。
