# Web3Security

这个仓库用于记录 Web3 安全事件的公开复盘材料，仅用于防御研究、安全学习和项目方自查。

## 仓库内容

每个事件目录通常包含：

- `report.md`：中文复盘，说明事件背景、影响范围、漏洞根因和修复建议。
- `test.t.sol`：Foundry fork 环境测试文件，用于在本地或授权环境中复核问题。

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

## 使用说明

- 所有内容仅用于安全学习、漏洞理解和防御加固。
- 测试文件只应在 fork、本地仿真或明确授权的环境中运行。
- 不要将任何复现代码、交易逻辑或测试流程用于真实链上未授权操作。
- 如果你是项目方，请优先关注报告中的根因分析和修复建议。

## 免责声明

本仓库内容仅供安全研究与防御建设参考。使用者需要遵守当地法律法规，并确保所有测试行为都在授权范围内进行。
