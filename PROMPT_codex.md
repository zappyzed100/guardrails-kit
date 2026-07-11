# Codex 用導入プロンプト

このリポジトリへ guardrails-kit を導入する。まず `README.md` と
`.guardrails/GUARDRAILS.md` §11 を読み、`scripts/install_kit.py` を対象リポジトリの
ルートで実行すること。既存設定との衝突は上書きせず、`CONFLICT` の理由と解消案を報告する。

導入後は Step 0→10 を順番に進める。各 Step を完了にする前に、対応する検査を実行して
結果を示すこと。`AGENTS.md` を共通規約の正本として読み、Claude Code を使う場合だけ
`CLAUDE.md` の `@AGENTS.md` import も配置する。

Codex では `.codex/hooks.json` を `/hooks` でレビューして信頼する。フックは
`apply_patch` の編集・Bash・SessionStart・Stop を対象にする。フックが拒否した操作を
迂回せず、理由を読み取って規約どおりに修正すること。
