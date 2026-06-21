# Contributing to CueFlow / 参与贡献

感谢你对 CueFlow（随读）的兴趣！🎉
Thanks for your interest in CueFlow!

## 提交 Issue / Reporting issues

- 报告 Bug 时，请附上：macOS 版本、芯片（Apple Silicon / Intel）、复现步骤、期望与实际结果。
- When reporting a bug, please include: macOS version, chip (Apple Silicon / Intel),
  steps to reproduce, and expected vs. actual behavior.

## 开发环境 / Dev setup

```bash
git clone https://github.com/binghe1980/cueflow.git
cd cueflow
./scripts/fetch_whisper_model.sh base   # 拉取离线语音模型 / fetch offline model (~144MB)
open notchprompt.xcodeproj
```

运行核心逻辑自测 / run the core self-tests:

```bash
swiftc notchprompt/ScriptTokenizer.swift notchprompt/AlignmentEngine.swift Tools/aligntest/main.swift -o .build-dd/aligntest && .build-dd/aligntest
swiftc notchprompt/CueScript.swift Tools/cuetest/main.swift -o .build-dd/cuetest && .build-dd/cuetest
```

## Pull Request

- 一个 PR 聚焦一件事；提交信息使用 [Conventional Commits](https://www.conventionalcommits.org/)（`feat:`、`fix:`、`docs:` …）。
- Keep PRs focused; use Conventional Commit messages.
- UI 改动请附前后截图 / Include before/after screenshots for UI changes.

## 许可证 / License

提交即表示你同意以 **MIT 协议**贡献你的代码。
By contributing, you agree your contributions are licensed under the **MIT License**.
