#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: MIT
#
# Advisory AI code review for a pull request.
#
# Reads PR metadata + per-file patches through the GitHub API, builds a prompt
# from the canonical ruleset (.github/AI_REVIEW.md), runs one headless agent
# CLI and posts (or idempotently updates) a single PR comment.
#
# Required env:
#   REPO        owner/name the PR belongs to
#   PR_NUMBER   pull request number
# Optional env:
#   ENGINE            claude | qoder | custom (default: claude)
#   MODEL             model name passed to the engine (optional)
#   MAX_DIFF_LINES    patch budget for the prompt (default: 4000)
#   AI_REVIEW_CMD     full shell command for ENGINE=custom or qoder override;
#                     reads the prompt on stdin, writes the report on stdout
#   REPORT_PATH       where to store the report (default: ai-review-report.md)
#   DRY_RUN           1 = print the comment body to stdout, do not post
#   GH_TOKEN          provided by gh CLI env

set -euo pipefail

REPO="${REPO:?REPO (owner/name) is required}"
PR_NUMBER="${PR_NUMBER:?PR_NUMBER is required}"
ENGINE="${ENGINE:-claude}"
MAX_DIFF_LINES="${MAX_DIFF_LINES:-4000}"
REPORT_PATH="${REPORT_PATH:-ai-review-report.md}"
DRY_RUN="${DRY_RUN:-0}"

RULES_FILE="$(cd "$(dirname "$0")/.." && pwd)/AI_REVIEW.md"
[ -r "$RULES_FILE" ] || { echo "ruleset not found at $RULES_FILE" >&2; exit 1; }

echo "::group::Fetch PR metadata"
gh api "repos/${REPO}/pulls/${PR_NUMBER}" > /tmp/pr.json
gh api "repos/${REPO}/pulls/${PR_NUMBER}/files" --paginate > /tmp/files.json
title="$(jq -r .title /tmp/pr.json)"
author="$(jq -r .user.login /tmp/pr.json)"
base="$(jq -r .base.ref /tmp/pr.json)"
head_sha="$(jq -r .head.sha /tmp/pr.json)"
draft="$(jq -r .draft /tmp/pr.json)"
changed_files="$(jq -r '.changed_files // ([.[]|.filename]|length)' /tmp/pr.json)"
additions="$(jq '[.[].additions] | add // 0' /tmp/files.json)"
deletions="$(jq '[.[].deletions] | add // 0' /tmp/files.json)"
echo "PR #${PR_NUMBER} '${title}' by @${author} (${base} <- ${head_sha:0:8}), ${changed_files} files +${additions}/-${deletions}"
if [ "$draft" = "true" ]; then
	echo "PR is a draft, skipping."
	exit 0
fi
echo "::endgroup::"

echo "::group::Build bounded diff"
diff_text=""
file_list=""
acc=0
truncated=false
nfiles="$(jq 'length' /tmp/files.json)"
for i in $(seq 0 $((nfiles - 1))); do
	fname="$(jq -r --argjson i "$i" '.[$i].filename' /tmp/files.json)"
	patch="$(jq -r --argjson i "$i" '.[$i].patch // "(no textual patch: binary, renamed-only, or too large for the API)"' /tmp/files.json)"
	nlines=$(printf '%s\n' "$patch" | wc -l)
	if [ $((acc + nlines)) -gt "$MAX_DIFF_LINES" ] && [ -n "$diff_text" ]; then
		truncated=true
		echo "diff budget of $MAX_DIFF_LINES lines reached, dropping $((nfiles - i)) remaining file(s)"
		break
	fi
	acc=$((acc + nlines))
	file_list+="- ${fname}"$'\n'
	diff_text+="diff --git a/${fname} b/${fname}"$'\n'"${patch}"$'\n'
done
COVERAGE="full"
if [ "$truncated" = "true" ]; then
	COVERAGE="partial (diff truncated at ${MAX_DIFF_LINES} lines; files after the budget were not reviewed)"
fi
echo "included diff: ${acc} lines"
echo "::endgroup::"

echo "::group::Run review engine (${ENGINE})"
prompt="You are performing an advisory code review of pull request #${PR_NUMBER} ('${title}', author @${author}, base branch ${base}) in the Nextcloud server repository.

Apply the ruleset below EXACTLY: use its rule IDs, its severity levels, and produce output in its 'Output format' section verbatim (nothing before or after it). Fill 'Coverage' as: ${COVERAGE}.

Only comment on lines present in the diff below. Prefer questions over assertions when you cannot verify something from the given context. Do not report issues that a linter/CI checker catches mechanically.

<ruleset>
$(cat "$RULES_FILE")
</ruleset>

Changed files:
${file_list}
Diff:
<diff>
${diff_text}
</diff>"

review_body=""
run_engine() {
	# Prompt is fed on stdin; the engine prints the report on stdout.
	case "$ENGINE" in
		claude)
			command -v claude >/dev/null || { echo "claude CLI not installed" >&2; exit 1; }
			[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "ANTHROPIC_API_KEY is empty, skipping" >&2; exit 2; }
			printf '%s' "$prompt" | claude -p --output-format text ${MODEL:+--model "$MODEL"}
			;;
		qoder)
			if [ -n "${AI_REVIEW_CMD:-}" ]; then
				printf '%s' "$prompt" | bash -c "$AI_REVIEW_CMD"
			else
				echo "ENGINE=qoder requires AI_REVIEW_CMD (the Qoder CLI has no confirmed headless print mode). Set AI_REVIEW_CMD to a command reading the prompt on stdin and printing the report." >&2
				exit 3
			fi
			;;
		custom)
			[ -n "${AI_REVIEW_CMD:-}" ] || { echo "ENGINE=custom requires AI_REVIEW_CMD" >&2; exit 3; }
			printf '%s' "$prompt" | bash -c "$AI_REVIEW_CMD"
			;;
		*)
			echo "unknown ENGINE '$ENGINE'" >&2
			exit 1
			;;
	esac
}

if ! review_body="$(run_engine)"; then
	rc=$?
	if [ "$rc" = "2" ]; then
		exit 0
	fi
	exit "$rc"
fi
[ -n "$(printf '%s' "$review_body" | tr -d '[:space:]')" ] || { echo "engine produced an empty report" >&2; exit 1; }
echo "::endgroup::"

model_note="${MODEL:-$ENGINE}"
comment="<!-- ai-review-bot -->
${review_body}

---
<sub>Advisory AI review (${model_note}, commit \`${head_sha:0:8}\`). Generated by \`.github/workflows/ai-review.yml\`; it is **not** a merge gate and every finding needs human triage per the [AI contribution policy](https://github.com/nextcloud/.github/blob/master/AI_POLICY.md).</sub>"

printf '%s\n' "$review_body" > "$REPORT_PATH"

if [ "$DRY_RUN" = "1" ]; then
	printf '%s\n' "$comment"
else
	echo "::group::Post PR comment"
	marker='<!-- ai-review-bot -->'
	existing_id="$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
		--jq "[.[] | select(.user.type == \"Bot\" and (.body | contains(\"${marker}\")))] | last | .id // empty")"
	if [ -n "$existing_id" ]; then
		gh api -X PATCH "repos/${REPO}/issues/comments/${existing_id}" -f body="$comment" --jq .html_url
	else
		gh api -X POST "repos/${REPO}/issues/${PR_NUMBER}/comments" -f body="$comment" --jq .html_url
	fi
	echo "::endgroup::"
fi
