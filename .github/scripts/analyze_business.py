#!/usr/bin/env python3
"""
ビジネス・マーケター視点でプロジェクトを分析し、GitHub Issueに投稿する。
"""

import os
import subprocess
import json
import sys
from datetime import datetime, timedelta

import anthropic
import requests

ANTHROPIC_API_KEY = os.environ["ANTHROPIC_API_KEY"]
GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
GITHUB_REPOSITORY = os.environ["GITHUB_REPOSITORY"]
LOOKBACK_DAYS = int(os.environ.get("LOOKBACK_DAYS", "7"))


def run(cmd: str) -> str:
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()


def collect_context() -> dict:
    since = (datetime.now() - timedelta(days=LOOKBACK_DAYS)).strftime("%Y-%m-%d")

    commits = run(f'git log --since="{since}" --pretty=format:"%h %s" --no-merges | head -40')
    diff_stat = run(f'git diff --stat HEAD~10 HEAD 2>/dev/null || git diff --stat HEAD 2>/dev/null | head -50')
    recent_diff = run(f'git log --since="{since}" --no-merges -p --diff-filter=AM -- "*.dart" | head -300')

    pubspec = ""
    try:
        with open("pubspec.yaml") as f:
            pubspec = f.read()
    except FileNotFoundError:
        pass

    screens = run("find lib/screens -name '*.dart' 2>/dev/null | sort")
    providers = run("find lib/providers -name '*.dart' 2>/dev/null | sort")
    services = run("find lib/services -name '*.dart' 2>/dev/null | sort")

    readme = ""
    try:
        with open("README.md") as f:
            readme = f.read()[:2000]
    except FileNotFoundError:
        pass

    open_issues = _fetch_github_issues()

    return {
        "commits": commits,
        "diff_stat": diff_stat,
        "recent_diff": recent_diff,
        "pubspec": pubspec,
        "screens": screens,
        "providers": providers,
        "services": services,
        "readme": readme,
        "open_issues": open_issues,
    }


def _fetch_github_issues() -> str:
    url = f"https://api.github.com/repos/{GITHUB_REPOSITORY}/issues"
    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}", "Accept": "application/vnd.github+json"}
    try:
        res = requests.get(url, headers=headers, params={"state": "open", "per_page": 20}, timeout=10)
        issues = res.json()
        if isinstance(issues, list):
            return "\n".join(f"#{i['number']} {i['title']}" for i in issues)
    except Exception:
        pass
    return "(取得できませんでした)"


def build_prompt(ctx: dict) -> str:
    today = datetime.now().strftime("%Y-%m-%d")
    return f"""あなたはスタートアップのビジネスアナリスト兼マーケターです。
以下はフィットネストラッカーのFlutterアプリ（iOS App Store向け、サブスク課金あり）の直近{LOOKBACK_DAYS}日間のGit情報とプロジェクト構造です。
ビジネス・マーケター視点で分析し、日本語で構造化レポートを作成してください。

分析日: {today}

## 直近コミット
{ctx['commits'] or '(なし)'}

## 変更ファイル統計
{ctx['diff_stat'] or '(なし)'}

## 変更コード抜粋 (Dart)
{ctx['recent_diff'][:4000] if ctx['recent_diff'] else '(なし)'}

## pubspec.yaml (依存ライブラリ)
{ctx['pubspec'][:2000]}

## 画面一覧
{ctx['screens']}

## プロバイダー一覧
{ctx['providers']}

## サービス一覧
{ctx['services']}

## 未解決Issue
{ctx['open_issues']}

---
以下の観点で分析し、Markdownでレポートを作成してください。

### レポート構成（必須）

1. **今週のビジネス進捗サマリー** (3行以内)
   - 何が進んだか、何が止まっているか

2. **マネタイズ・収益への影響度**
   - サブスク/課金フローに関する変更・リスク・未実装
   - 評価: 🟢良好 / 🟡要注意 / 🔴リスクあり

3. **ユーザー獲得・リテンションへの影響**
   - オンボーディング、通知、AI機能の価値提供状況
   - App Storeレビュー対応状況

4. **ビジネスリスク TOP3**
   - 技術的負債・バグリスクのうち、ユーザー離脱や収益損失に直結するもの
   - 各リスクに優先度（高/中/低）と推奨アクションを付ける

5. **次の1週間でやるべきこと（優先順）**
   - ビジネスインパクトが高い順に3〜5項目
   - 各項目に担当（エンジニア/マーケター/PdM）を示す

6. **競合・市場視点からの気づき**
   - 実装中の機能が市場でどんな位置づけか、差別化できているか

レポートは経営者・マーケターが読むことを想定し、技術用語を最小化して簡潔に書いてください。
"""


def analyze(ctx: dict) -> str:
    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    message = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=2048,
        messages=[{"role": "user", "content": build_prompt(ctx)}],
    )
    return message.content[0].text


def post_issue(report: str) -> str:
    today = datetime.now().strftime("%Y-%m-%d")
    title = f"[AI週次レポート] ビジネス・マーケター分析 {today}"
    body = f"""> このIssueはGitHub ActionsのAI分析により自動生成されました。

{report}

---
*分析対象期間: 直近{LOOKBACK_DAYS}日間 | モデル: claude-opus-4-8*
"""

    url = f"https://api.github.com/repos/{GITHUB_REPOSITORY}/issues"
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
    }
    payload = {
        "title": title,
        "body": body,
        "labels": ["business-report", "ai-analysis"],
    }
    res = requests.post(url, headers=headers, json=payload, timeout=15)
    res.raise_for_status()
    return res.json()["html_url"]


def ensure_labels():
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
    }
    base = f"https://api.github.com/repos/{GITHUB_REPOSITORY}/labels"
    for label, color, desc in [
        ("business-report", "0075ca", "AI生成ビジネスレポート"),
        ("ai-analysis", "e4e669", "AI自動分析"),
    ]:
        requests.post(base, headers=headers, json={"name": label, "color": color, "description": desc}, timeout=10)


if __name__ == "__main__":
    print("=== コンテキスト収集中 ===")
    ctx = collect_context()

    print("=== Claude APIで分析中 ===")
    report = analyze(ctx)

    print("=== GitHubラベル確認 ===")
    ensure_labels()

    print("=== Issue投稿中 ===")
    issue_url = post_issue(report)

    print(f"✅ レポート投稿完了: {issue_url}")
    print("\n--- レポート内容 ---")
    print(report)
