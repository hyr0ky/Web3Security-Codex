# Huma Finance V1 BaseCreditPool 漏洞复盘 - 2026-05-11

这是一份公开版复盘报告，基于本地 fork 验证整理。原始 trace、RPC 输出、扫描缓存、临时文件路径等内部材料不会放到公开仓库。

## 一句话总结

Huma Finance 已废弃的 V1 `BaseCreditPool` 在 Polygon 上存在状态机缺陷：普通用户可以先给自己创建 `Requested` 状态的信用额度，再通过公开刷新逻辑把它推进到 `GoodStanding`，最后触发提款逻辑从资金池借出 USDC/USDC.e。

## 信息来源

- ExVulSec：`https://x.com/exvulsec/status/2053864262058340556`
- Blockaid：`https://x.com/blockaid_/status/2053855152688202098`
- Phalcon：`https://app.blocksec.com/phalcon/explorer/tx/polygon/0x7b8d641d76affcc029fd0e0f06ab81ad675b1da21ef79b82e1343016040ba359`
- PolygonScan：`https://polygonscan.com/tx/0x7b8d641d76affcc029fd0e0f06ab81ad675b1da21ef79b82e1343016040ba359`

## 交易基本信息

- 链：Polygon
- 攻击交易：`0x7b8d641d76affcc029fd0e0f06ab81ad675b1da21ef79b82e1343016040ba359`
- 区块：`86725404`
- 时间：`2026-05-11 22:19:25 UTC+8`
- 攻击者 EOA / Top Gainer：`0x13b44e416e0f66359502e843af2e1191f1260daf`
- 攻击者创建的 borrower/executor：`0x44d4a434ae1529106e4b801315e22721978022a3`
- 前置 setup 交易：`0x0adf9953c4e2506ffd4526ceee962a9bb61c573eaef60f669605cca68d0ef5aa`
- 公开 refresh 交易：`0x7126ae1d8e8d1e0c0f1c598de16a035cf309d6cc556e73edc2847de2b5777e5e`

## 受害资金池与资金流

| 资金池 | 实现合约 | 资产流出 |
|---|---|---:|
| `0x3ebc1f0644a69c565957ef7ceb5aeafe94eb6fce` | `0x57107d02c2b70e09ad77240dbde7ad77fe91ea1c` | `82,315.571143 USDC` |
| `0x95533e56f397152b0013a39586bc97309e9a00a7` | `0x57107d02c2b70e09ad77240dbde7ad77fe91ea1c` | `17,290.759830 USDC.e` |
| `0xe8926adbfadb5da91cd56a7d5acc31aa3fdf47e5` | `0x2cffaaf7885530e1c5a9684ebbe397d6f1de48d8` | `1,783.970571 USDC.e` |

Phalcon/trace 里看到的攻击者总收益约为 `101,390.301544` 美元稳定币。

## 漏洞根因

问题不在单个 transfer，而在信用额度状态机可以被普通用户绕过审批流程推进。

申请信用额度的入口是公开函数。普通调用者可以为自己创建一条信用记录。此时信用记录状态是 `CreditState.Requested`，按正常业务理解，这一步应该只是“申请中”，还不能提款。

关键问题出在账户刷新逻辑。这个入口同样公开可调用；当系统认为已经经过了计费周期后，内部更新逻辑可以把 borrower 的信用记录从 `Requested` 推进到 `GoodStanding`，但没有确认 EA、管理员或授信服务是否真的批准过这笔额度。

提款逻辑后续只检查调用者的信用记录是不是 `GoodStanding` 或 `Approved`。一旦前面的刷新逻辑把状态推进成功，borrower 就可以触发提款，资金池会把底层 USDC/USDC.e 转给 borrower。

所以根因是：公开入口组合形成了“申请额度 -> 公开刷新状态 -> 直接提款”的未授权状态转换链路。

## 风险链路（概念）

这个问题可以抽象成一个状态机风险：

`未审批申请` -> `公开刷新状态` -> `被系统视为可提款状态` -> `资金池资产流出`。

对防守方来说，重点是检查“申请、刷新、提款”之间是否存在缺失授权的状态推进。

## 防御排查建议

- 检查申请、刷新、提款等状态转换是否都需要可信角色或明确审批结果。
- 检查已废弃或暂停的资金池是否仍保留余额，且仍允许普通用户触发核心业务函数。
- 检查 `Requested`、`Approved`、`GoodStanding` 等信用状态之间是否存在公开函数可以绕过人工或服务端审批直接推进。
- 检查提款函数是否只依赖状态字段，而没有重新确认授信来源、额度审批、借款人身份和池子启用状态。
- 对废弃 V1 池执行余额迁移、暂停公开入口，并在状态机转换处补充审批来源校验。

## 附件说明

同目录下保留 `test.t.sol`，用于安全研究人员在本地 fork 环境中复核根因。测试文件使用新生成的 Foundry 地址和自研测试合约，不依赖历史攻击者合约。

## 安全说明

- 本 PoC 仅用于 fork 环境复现和防御研究。
- 不要把攻击交易广播到真实链上。
- 如果要判断当前是否还能获利，需要重新检查最新链上状态。
