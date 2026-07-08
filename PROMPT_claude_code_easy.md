# PROMPT_claude_code_easy.md — 新規リポジトリ限定・簡易導入（数分で完了・保証は通常版より弱い）

使い方: **まっさらな新規リポジトリにだけ**使う（既存コードがあるなら
`PROMPT_claude_code_existing.md`。通常の新規導入は `PROMPT_claude_code.md`）。
下の「入力」の ★ を埋め、罫線から下の全文をコピーして、リポジトリルートで起動した
Claude Code の**最初のメッセージ**として貼り付ける。

## これは何を削っているか（必ず読むこと）

`PROMPT_claude_code.md`（通常版）が数時間かかる理由は「設定を書く」ことではなく、
**各規則を実際に違反させて落ちることを1つずつ実測する**（GUARDRAILS.md §10 実行規律2:
完了=実行結果・自己申告ではない）・**CIへ実際に push して緑/赤を実測する**・**ログ単一
出口や確率的コンポーネントラッパーを実コードとして書く**、という検証そのものに時間が
かかっているため。この簡易版はそれを意図的に削って速さを優先する。削った結果:

- **個別の違反注入検証を省略する**。通常版は hard 規則ごとに1つずつ違反ファイルを注入し
  規則IDで落ちることを確認するが、この簡易版は**代表的な違反を1本のスモークテストに
  まとめて**確認するだけ。個々の規則の正規表現が意図どおりかは**未検証のまま**残る。
- **CI（GitHub Actions）の実 push 検証を省略する**。`guardrails-ci.yml` は配置するが、
  正常PRで緑になること・違反PRで赤になることは実測しない。**CIが本当に機能しているかは
  未確認のまま**。
- **ログ単一出口・確率的コンポーネントラッパーの参照実装はカタログの paste-block を
  そのまま貼るだけ**で、違反注入による実測検証はしない。
- **E2E・操作レール（Playwright MCP 等）の配線は行わない**（必要になったら後で追加する）。
- **`pre-commit autoupdate` は行わない**（キット同梱の固定 rev のまま使う）。

省略しないもの（fail-open を防ぐため必須）:
- `.claude/settings.json` 配置直後の `/hooks` での有効化確認（ここを省くと §2/§2b/§2c の
  防壁が静かに機能しない状態になる）。
- `check_structure.py`・commit-msg フック・`guard_git_bypass` が**揃って**動くことの
  最低限のスモークテスト（個別規則の正しさは未実測でも、機構自体が生きているかは確認する）。

**結論: この簡易版で作ったリポジトリは「配線はされているが末端まで実証されていない」
規則を抱えたまま運用が始まる。**壁打ち中や実タスクの中で、ある規則がすり抜けている
（または過検知する）ことに気づいたら、その規則だけ `PROMPT_claude_code.md` の該当 Step
の手順（違反注入→実測）をその場で行って埋める。全規則をきちんと実証したいなら、
最初から `PROMPT_claude_code.md` を使うこと。

---

## 入力（ユーザー記入欄）

- 言語: ★（例: `TypeScript(React) + Supabase`。`bindings/catalog.md` に列がある言語なら列IDだけでも可）
- レイヤー構成と依存方向: ★（例: `app/ → engine/ の一方向`）
- 確率的コンポーネント: ★ 有 / 無（有なら: コンポーネント名・本体の呼び出し関数名）
- 採用するバインディング列: ★（`bindings/catalog.md` の列ID@版）
- GitHub リモート URL: ★（無ければ「なし」——このプロンプトでは push・CI実測はしない）
- 特記事項: ★（無ければ「なし」）

## 任務

このリポジトリに guardrails-kit の機構を**配線だけ**敷設する。詳細な契約・完了条件の
正本は `GUARDRAILS.md` だが、このプロンプトでは §11 Step 0〜10 の**個別違反注入・CI実測・
参照実装の実コード化を圧縮**して進める（上の「これは何を削っているか」のとおり）。

## 手順

### Step 1 — 配置
`GUARDRAILS.md` が無ければ zip を配置する:
```bash
python3 -m zipfile -e guardrails-kit-*.zip .guardrails-kit-src   # zip の場合のみ
python3 .guardrails-kit-src/scripts/install_kit.py
```
（`python3` が無ければ `py -3` / `uv run --no-project`。ネストしていれば探索する——
`PROMPT_claude_code.md` の該当コマンドと同じ）
`.claude/settings.json` 配置直後、ユーザーに「`/hooks` で PreToolUse: Bash・
Edit|Write|MultiEdit / PostToolUse / Stop / SessionStart の4種5エントリの有効化を確認し、
承認したら『続行』と返信してください」とだけ依頼して待つ（ここは省略しない）。

### Step 2 — 骨格とバインディング充填（一括）
1. `AGENTS.md.template` → `AGENTS.md`、`CLAUDE.md.template` → `CLAUDE.md` を完成させる
   （★ を全置換）。最小の `README.md` を作成。
2. `scripts/repo_scan.py` の BINDING・`scripts/dev.py` の `COMMANDS`・
   `.claude/hooks/post_edit_format.py`/`post_edit_lint.py` の `DISPATCH`・
   `.pre-commit-config.yaml`・`.github/workflows/guardrails-ci.yml` の BINDING マーカー
   以下へ、採用列の paste-block を一括で充填し `BINDING-SOURCE: 列ID@版` を刻印する。
3. ログ単一出口・（確率的コンポーネントが有るなら）ラッパーの参照実装をカタログから
   貼る（違反注入検証はしない）。
4. `uv run scripts/generate_structure.py` で STRUCTURE.md を初回生成。

### Step 3 — pre-commit 導入
`uv tool install pre-commit` → `pre-commit install`（`autoupdate` は行わない）。

### Step 4 — スモークテスト（まとめて1回）
1. 1つのダミーファイルに複数の違反（例: layer-violation を起こす import・print 直呼び・
   末尾空白）を同時に仕込み、`uv run scripts/check_structure.py` が該当する規則IDを
   まとめて報告することを確認して除去する。
2. `git commit --no-verify` と `git push -f` が `guard_git_bypass` にブロックされることを
   1回ずつ実測する。
3. `uv run scripts/check_guard_corpus.py` が全行 PASS することを確認する。
4. 不正な commit メッセージ（規約違反プレフィックス）で1回落ちることを確認する。

### Step 5 — 完了報告
以下を明示して終える（自己申告での「完了」にしない——できたことと省略したことを
両方はっきり書く）:
- Step 1〜4 の実行結果（成功出力の抜粋）。
- **未実証のまま残っている項目のリスト**: 個別規則の違反注入未実施一覧・CI未実測・
  E2E/操作レール未配線・ログ/ラッパー実装の違反注入未実施。
- 「本格的に検証したい場合は `PROMPT_claude_code.md` の該当 Step を後から個別に実施
  できる」旨の一言。
