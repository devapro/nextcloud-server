<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Best open issues for Docker + Chrome Connect testing

Source: open issues on [nextcloud/server](https://github.com/nextcloud/server/issues)  
Screened: **60** most recently listed open issues (6×10 batches; stop once ≥10 strong fits; cap 100)  
Stack: local `docker/` compose + Google Chrome CDP (`http://localhost:8080`, `/index.php/…`)  
Selected: **10** strongest **`yes`** fits (clear Chrome UI repro, no LDAP/Talk/SMTP/object-storage)

| # | Issue | Area | Why it fits |
|---|-------|------|-------------|
| 1 | [#63512](https://github.com/nextcloud/server/issues/63512) — PDF viewer broken due to `.json`/`.ftl` rewrite rules | files_pdfviewer / Apache | Matches this Docker Apache stack exactly; open a PDF in Files and check `locale.json` / `viewer.ftl` (200 vs 404). |
| 2 | [#63712](https://github.com/nextcloud/server/issues/63712) — System tag multibyte name >64 bytes → 500 | tags / Files | Pure Files UI + Postgres; create/rename tag with 63 ASCII + one Cyrillic character. |
| 3 | [#63487](https://github.com/nextcloud/server/issues/63487) — Comment entry field disappears when switching sidebar tabs | comments / Files | Sidebar Activity → Versions → Activity; comment input missing until reload. |
| 4 | [#63680](https://github.com/nextcloud/server/issues/63680) — Upload status not fully visible on multi-file upload | Files toolbar | Upload several files; confirm progress text (time/%/counts) is clipped. |
| 5 | [#63688](https://github.com/nextcloud/server/issues/63688) — Left group share cannot be rejoined | sharing | Two users + group share; leave → Deleted shares → restore fails. |
| 6 | [#63503](https://github.com/nextcloud/server/issues/63503) — Existing tag missing in tag management | tags / Settings | Create tags; compare Settings → Basic settings tag list vs file tag picker. |
| 7 | [#63515](https://github.com/nextcloud/server/issues/63515) — Lack of some translations in v34 | settings / l10n | Set UI to German; Admin settings section titles stay English. |
| 8 | [#63561](https://github.com/nextcloud/server/issues/63561) — Visibility popup auto-opens first dropdown | profile / Settings | Personal profile visibility popup; first dropdown opens and obscures dialog. |
| 9 | [#63159](https://github.com/nextcloud/server/issues/63159) — `hide_disabled_user_shares` meaning/default changed | sharing | Share → disable owner → check Shared with you + public link; toggle via `occ`. |
| 10 | [#63252](https://github.com/nextcloud/server/issues/63252) — Weather Status wrong language (e.g. Russian) | dashboard | Personal language → `es` (or similar); Dashboard weather widget locale wrong. |

## Chrome checks (short)

1. **#63512** — Upload/open PDF → viewer renders; DevTools: `locale.json` / `viewer.ftl` = 200.  
2. **#63712** — Files → tags → long multibyte name → UI/HTTP 500.  
3. **#63487** — File sidebar tab switch → comment field gone.  
4. **#63680** — Multi upload → toolbar status readable end-to-end.  
5. **#63688** — Restore left group share from Deleted shares.  
6. **#63503** — Tag assignable on file but absent in tag management.  
7. **#63515** — Non-English UI → Admin “Personal” / “Administration” labels.  
8. **#63561** — Visibility popup → first dropdown should stay closed on open.  
9. **#63159** — Disabled sharer: internal + public share visibility vs `hide_disabled_user_shares`.  
10. **#63252** — Weather widget follows selected language, not English/Russian fallback.

## Screening notes

- Sub-agents returned **14 `yes`** and **17 `maybe`** across 60 issues.  
- Preferenced reproducible **bugs** over unimplemented enhancements / design-only items.  
- Dropped or deferred `maybe` items needing Contacts app, Calendar, SMTP, SSE encryption fixtures, or heavy `occ`/SQL preview surgery.  
- Strong runners-up (not in top 10): [#63703](https://github.com/nextcloud/server/issues/63703) profile hovercard, [#63654](https://github.com/nextcloud/server/issues/63654) favorite apps in top bar, [#63548](https://github.com/nextcloud/server/issues/63548) extra public-link option, [#63491](https://github.com/nextcloud/server/issues/63491) Smart Picker in comments.
