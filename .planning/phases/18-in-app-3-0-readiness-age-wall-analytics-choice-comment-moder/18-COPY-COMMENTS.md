# EhPanda 3.0: comment report, posting warning and blocking copy

APPROVED by the owner, msg 1780 (2026-11-05), all six languages, including the Blocked Users list in Settings (owner chose "Include the list"). Author: Camo. Delivered in msg 1777.
Decisions this is written for: reports go to E-Hentai only (owner msg 1753); a comment that trips the filter gets a warning and can be posted anyway (owner msg 1765); a blocked user's comment collapses into a "comment from a user you've blocked" row instead of disappearing (owner msg 1765).

`%@` = the commenter's name. `{site}` = the gallery's site name as shown elsewhere in the app (E-Hentai or ExHentai). Pick whichever the developer finds simpler; the sentences work with either.

## One term per concept

| Concept | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| comment (existing) | comment | Kommentar | 댓글 | コメント | 评论 | 留言 |
| post (a comment) | post | veröffentlichen | 게시 | 投稿 | 发布 | 發表 |
| report | report | melden | 신고 | 通報 | 举报 | 檢舉 |
| block / unblock | block / unblock | blockieren / Blockierung aufheben | 차단 / 차단 해제 | ブロック / ブロックを解除 | 屏蔽 / 取消屏蔽 | 封鎖 / 解除封鎖 |

zh-Hans already uses 屏蔽 for "Excluded Uploaders" (屏蔽的上传者). That's the word Chinese users expect for blocking a person too, and both mean "hide what they post", so I kept it rather than adding 拉黑. zh-Hant's exclusions use 排除, so 封鎖 doesn't clash there.

---

## 1. Report

In each comment's menu. It opens the site's own report page, because reports go to E-Hentai only. The confirmation tells people they're leaving the app and what to mention, since the site's form is for the gallery, not one comment.

No per-comment report link was found in the prep research. If research shows the site does offer one, drop the second sentence of the body.

| Key (suggested) | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| comment.report | Report on {site} | Auf {site} melden | {site}에 신고 | {site} で通報 | 在 {site} 上举报 | 在 {site} 上檢舉 |
| comment.report.confirm_title | Report this comment? | Diesen Kommentar melden? | 이 댓글을 신고할까요? | このコメントを通報しますか？ | 要举报这条评论吗？ | 要檢舉這則留言嗎？ |
| comment.report.confirm_body | This opens the gallery's report page on {site}, where the site's staff handle reports. Mention that it's about a comment by %@. | Dadurch öffnet sich die Meldeseite der Galerie auf {site}, wo das Team der Seite Meldungen bearbeitet. Gib dort an, dass es um einen Kommentar von %@ geht. | {site}의 갤러리 신고 페이지가 열리며, 신고는 사이트 운영진이 처리합니다. %@ 님의 댓글에 대한 신고라고 적어 주세요. | {site} のギャラリー通報ページが開きます。通報はサイトの運営チームが対応します。%@ さんのコメントについての通報であることを書き添えてください。 | 将打开 {site} 上该画廊的举报页面，举报由网站管理人员处理。请注明举报的是 %@ 的评论。 | 將開啟 {site} 上這個畫廊的檢舉頁面，檢舉由網站管理人員處理。請註明檢舉的是 %@ 的留言。 |
| comment.report.open | Open Report Page | Meldeseite öffnen | 신고 페이지 열기 | 通報ページを開く | 打开举报页面 | 開啟檢舉頁面 |

Cancel uses the existing `cancel`.

---

## 2. Posting warning

Shown when the filter matches, after tapping Post and before anything is sent. It never names the matched word. "Edit" is the default button and keeps the text as typed.

| Key (suggested) | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| comment.filter.title | Post this comment? | Diesen Kommentar veröffentlichen? | 이 댓글을 게시할까요? | このコメントを投稿しますか？ | 要发布这条评论吗？ | 要發表這則留言嗎？ |
| comment.filter.body | It may contain hateful, threatening or harassing language. | Er enthält möglicherweise hasserfüllte, bedrohliche oder belästigende Sprache. | 혐오, 위협 또는 괴롭힘에 해당하는 표현이 포함되어 있을 수 있습니다. | 差別的、脅迫的、または嫌がらせにあたる表現が含まれている可能性があります。 | 其中可能含有仇恨、威胁或骚扰性的言论。 | 其中可能含有仇恨、威脅或騷擾性的言論。 |
| comment.filter.edit | Edit | Bearbeiten | 수정 | 編集する | 编辑 | 編輯 |
| comment.filter.post_anyway | Post Anyway | Trotzdem veröffentlichen | 그래도 게시 | このまま投稿 | 仍要发布 | 仍要發表 |

The same warning applies to edits of an existing comment (L21).

---

## 3. Blocking

| Key (suggested) | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| comment.block | Block %@ | %@ blockieren | %@ 님 차단 | %@ さんをブロック | 屏蔽 %@ | 封鎖 %@ |
| comment.block.confirm_title | Block %@? | %@ blockieren? | %@ 님을 차단할까요? | %@ さんをブロックしますか？ | 要屏蔽 %@ 吗？ | 要封鎖 %@ 嗎？ |
| comment.block.confirm_body | Their comments will be collapsed on this device. You can unblock them anytime. | Die Kommentare dieser Person werden auf diesem Gerät eingeklappt. Du kannst die Blockierung jederzeit aufheben. | 이 기기에서 이 사용자의 댓글이 접혀서 표시됩니다. 언제든지 차단을 해제할 수 있습니다. | このデバイスでは、このユーザーのコメントが折りたたまれて表示されます。ブロックはいつでも解除できます。 | 在此设备上，此用户的评论将被折叠。你可以随时取消屏蔽。 | 在此裝置上，這位使用者的留言將會收合。你可以隨時解除封鎖。 |
| comment.block.confirm | Block | Blockieren | 차단 | ブロック | 屏蔽 | 封鎖 |
| comment.blocked_row | Comment from a user you've blocked | Kommentar von einer Person, die du blockiert hast | 차단한 사용자의 댓글 | ブロックしたユーザーのコメント | 来自已屏蔽用户的评论 | 來自已封鎖使用者的留言 |
| comment.blocked_row.show | Show | Anzeigen | 보기 | 表示 | 显示 | 顯示 |
| comment.blocked_row.hide | Hide | Ausblenden | 숨기기 | 隠す | 隐藏 | 隱藏 |
| comment.unblock | Unblock %@ | Blockierung von %@ aufheben | %@ 님 차단 해제 | %@ さんのブロックを解除 | 取消屏蔽 %@ | 解除封鎖 %@ |

The collapsed row never shows the blocked user's name, so the block also takes their name off the page. "Show" reveals that one comment once; it stays blocked.

### Blocked Users list in Settings (APPROVED, owner msg 1780: include the list)

| Key (suggested) | en | de | ko | ja | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| blocked_users | Blocked Users | Blockierte Personen | 차단한 사용자 | ブロックしたユーザー | 已屏蔽的用户 | 已封鎖的使用者 |
| blocked_users.footer | Comments from these users are collapsed on this device. | Kommentare dieser Personen werden auf diesem Gerät eingeklappt. | 이 기기에서 이 사용자들의 댓글은 접혀서 표시됩니다. | このデバイスでは、これらのユーザーのコメントは折りたたまれて表示されます。 | 在此设备上，这些用户的评论会被折叠。 | 在此裝置上，這些使用者的留言會收合。 |
| blocked_users.empty | You haven't blocked anyone. | Du hast niemanden blockiert. | 차단한 사용자가 없습니다. | ブロックしたユーザーはいません。 | 你还没有屏蔽任何人。 | 你還沒有封鎖任何人。 |
| blocked_users.unblock (swipe action) | Unblock | Blockierung aufheben | 차단 해제 | ブロックを解除 | 取消屏蔽 | 解除封鎖 |

---

## Not covered here

- Contact details: not added now (Ampo msg 1774): reporting stays E-Hentai only; a published contact link (GitHub Issues on the website) belongs to the distribution phase.
- VoiceOver labels for the comment menu: the visible labels above work as they are.
