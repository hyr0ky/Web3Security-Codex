# Web3Security

这个仓库用于记录 Web3 安全事件的公开复盘材料，仅限防御研究、学习和安全建设使用。

## 仓库内容

每个事件目录通常包含：

- `report.md`：中文公开复盘，说明事件背景、影响范围、漏洞根因和防御排查建议。
- `test.t.sol`：Foundry fork 环境测试文件，用于在本地安全环境中复核根因。

目录结构：

```text
<chain>/<yyyymmdd>/<incident-slug>/report.md
<chain>/<yyyymmdd>/<incident-slug>/test.t.sol
```

示例：

```text
polygon/20260511/huma-basecreditpool/report.md
polygon/20260511/huma-basecreditpool/test.t.sol
```

## 使用边界

- 仅用于 Web3 安全学习、漏洞理解、防御排查和项目方自查。
- 不用于真实链上攻击、未授权测试、资产转移或任何违法行为。
- 报告正文会尽量避免提供可直接用于批量寻找目标的攻击检索说明。
- 如果你是项目方，请优先关注报告中的根因分析和防御排查建议。

## 安全说明

所有测试都应只在 fork、本地仿真或授权环境中运行。请不要把任何复现代码或交易逻辑广播到真实链上。
