# メンテナーへの質問案: --restore-permissions だけでリンクの所有者も戻すか（#3848 の後続）

10-22 に案 1 を https://github.com/duplicati/duplicati/issues/7524 として投稿（利用者の指示）。コード変更なし。master 98067e41 を読んで作成（2026-10-22）。

## 確かめた事実
- 検証済み（コード）: リンクへのメタデータ適用は `--restore-symlink-metadata` のときだけ。`FileRestoreDestinationProvider.cs:235` で `!restoreSymlinkMetadata && IsSymlink` なら早期 return。新旧どちらの restore も `RestoreHandler.ApplyMetadataAsync`（RestoreHandler.cs:1399）→ この `WriteMetadata` を通る（新エンジンは FileProcessor.cs:1146 から）。
- 検証済み（コード）: 所有者は `SystemIOLinux.SetMetadata` の `restorePermissions && "unix:uid-gid-perm"`（SystemIOLinux.cs:297）の中だけ。`PosixFile.SetUserGroupAndPermissions`（PosixFile.cs:400）は `SetOwner`（Mono の symlink entry では lchown、#7461 の PR 本文で実測済み）＋リンク以外にだけ chmod。→ リンクの所有者には 2 つのオプションが両方要る。
- 検証済み（gh）: #7461 は 2026-10-19 マージ、レビュー・コメントなし。#3848 は closed。#3848 の唯一のコメント（ts678）は 2.0.3.7 の changelog「No longer restoring metadata on symlinks by default, as that updated the targets」を引いている → 既定で外したのはリンク先が変わるため（ドキュメント根拠）。
- 推測: #3848 の報告者が期待したのは「--restore-permissions でリンクも本来の所有者」。報告文は "all files seem to get their acls back correctly … except for symlinks"。
- macOS（コードのみ、未検証）: Linux と同じ `SystemIOLinux`。`--restore-permissions` の中では所有者に加えて ACL（`SetAcl(..., followSymlink:false)`）と file flags（`SetFileFlags(..., followSymlink:false)`）もリンク自身に当たる。A にするなら「所有者だけ」か「ACL/flags も」かを決める必要がある。
- Windows（コード）: `SystemIOWindows.SetMetadata` は所有者を保存・復元しない（アクセス規則と保護フラグだけ）。所有者の話は Windows には無い。A をアクセス規則に広げるかは別の問い。
- 実装上の注意（コード）: `SetMetadata` の先頭で拡張属性 `unix-ext:*` が `restorePermissions` に関係なく当たる（follow する setxattr。未 PR の `fix/restore-symlink-xattr` が lsetxattr に直す）。A の実装は `SetMetadata` を丸ごと呼ばず、所有者だけを当てる経路にする必要がある。

## 置き場所の候補
1. **新しい Issue（お勧め）** — 方針の質問だけで独立している。closed の #3848 より見られやすい。未 PR の `fix/restore-symlink-metadata-help`（ヘルプ文）の文面が答え次第で変わるので、先に決めたい。
2. #3848 にコメント — 経緯はそろっているが closed で、kenkendk の目に入りにくい。
3. `fix/restore-symlink-metadata-help` の PR を出すとき、本文の末尾に質問として入れる — PR が 1 つで済むが、ヘルプ文の修正と方針の質問が混ざり、答えで本文が変わる。

---

## 案 1: 新しい Issue

Title: Should --restore-permissions alone restore the owner of symlinks?

Since #7461 (for #3848), a restored symlink gets its owner back via `lchown`, but only when both `--restore-symlink-metadata` and `--restore-permissions` are set: `FileRestoreDestinationProvider.WriteMetadata` returns early for links without the first (FileRestoreDestinationProvider.cs:235), and the owner is set in `SystemIOLinux.SetMetadata` only with the second (SystemIOLinux.cs:297). With `--restore-permissions` alone, links are still restored as root:root, which I think is what #3848 was about.
`--restore-symlink-metadata` was made opt-in because metadata used to be written through the link to its target. `lchown` does not follow the link, so the owner could be applied without that risk.

Options:
- A: `--restore-permissions` alone also restores the owner of symlinks (on macOS possibly also the ACL and flags, which are already set on the link itself). Timestamps and other metadata still need `--restore-symlink-metadata`. This changes what existing restores with `--restore-permissions` do to links.
- B: keep it as is, and say in the help text that the owner of a link needs both options.

I can send a PR for either. Which do you prefer?

## 案 2: #3848 へのコメント

After #7461, a restored symlink gets its owner back, but only with both `--restore-symlink-metadata` and `--restore-permissions` (FileRestoreDestinationProvider.cs:235, SystemIOLinux.cs:297). With `--restore-permissions` alone it is still root:root, as reported here.
The owner is now set with `lchown`, so it would be safe to apply it with `--restore-permissions` alone, without the rest of the symlink metadata. That would change what existing restores do to links, though.
@kenkendk would you prefer (A) `--restore-permissions` alone restoring the owner of links, or (B) keeping it as is and documenting that both options are needed? I can send a PR for either.

## 案 3: ヘルプ文 PR の本文末尾に足す段落

### Open question
The owner of a link is still restored only with both `--restore-symlink-metadata` and `--restore-permissions` (FileRestoreDestinationProvider.cs:235). `lchown` does not follow the link, so `--restore-permissions` alone could restore it, which is what #3848 asked for, but it would change what existing restores do. This PR documents the current behaviour (B). If you prefer A, I can change that in a follow-up PR.
