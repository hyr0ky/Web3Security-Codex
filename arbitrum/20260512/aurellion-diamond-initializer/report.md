# Aurellion Labs ERC20 Pull Incident 复盘 - 2026-05-12

这是一份公开版复盘报告，基于本地 fork 验证整理。原始 trace、RPC 输出、扫描缓存、临时文件路径等内部材料不会放到公开仓库。

## 一句话总结

Aurellion Labs 事件中的核心问题不是 USDC 本身，而是一个 Diamond/拉取合约流程被攻击者初始化并改造：攻击者通过 DiamondCut 加入自定义逻辑，利用部分地址此前授予该 Diamond 地址的 ERC20 allowance 转走 USDC。

## 信息来源

- ExVulSec：`https://x.com/exvulsec/status/2054151310245851483`
- Arbiscan：`https://arbiscan.io/tx/0x19cbafae517791e7e73403313d70440abf60558350e419df05c04f816998fe0a`
- Phalcon：`https://app.blocksec.com/phalcon/explorer/tx/arbitrum/0x19cbafae517791e7e73403313d70440abf60558350e419df05c04f816998fe0a`

## 交易基本信息

- 链：Arbitrum
- 攻击交易：`0x19cbafae517791e7e73403313d70440abf60558350e419df05c04f816998fe0a`
- 区块：`462014667`
- 攻击者 EOA：`0x9f49591a3bf95b49cd8d9477b4481ce9da68d5ca`
- 攻击者临时合约：`0x4d7759e69cc973d338a1ea2fdb125c2b818f4d7e`
- 被滥用 Diamond / 拉取合约：`0x0adc63e71b035d5c7fdb1b4593999fa1f296f1b2`
- 资产：Arbitrum USDC `0xaf88d065e77c8cc2239327c5edb3a432268e5831`
- 影响：约 `456,442.536622 USDC` 被转移

## 资金流概览

| 来源地址 | USDC 流出 |
|---|---:|
| `0x2e933518068b1cfc9746d94762ef2eddd39c6048` | `450,999.723188 USDC` |
| `0xa90714a15d6e5c0eb3096462de8dc4b22e01589a` | `3.000000 USDC` |
| `0xeced2d37e5edcfc67ffb74c655416f893d20793e` | `1.281433 USDC` |

这些 USDC 先进入被滥用的 Diamond / 拉取合约，再被转到攻击者临时合约，最后转给攻击者 EOA。

## 漏洞根因

本次事件的核心不是 USDC 代币漏洞，而是 Diamond 风格合约流程被攻击者控制后，变成了 ERC20 allowance 拉取器。

链上攻击交易中，攻击者先创建临时执行合约，再通过 `initialize(address)` 和 `diamondCut(...)` 路径让 Diamond 加入攻击者控制的 facet。新增逻辑在 Diamond 地址上下文中执行，因此可以调用 `USDC.transferFrom(...)`，把已授权地址上的 USDC 拉到 Diamond，再把余额清扫到攻击者控制地址。

根因可以概括为：Diamond 初始化/升级控制没有被有效锁定，加上部分地址对该 Diamond 地址存在 ERC20 授权，最终形成资产被拉走的风险。

## 风险链路（概念）

`Diamond 初始化/升级控制失效` -> `攻击者加入自定义 facet` -> `使用既有 ERC20 授权拉取资产` -> `清扫到攻击者地址`。

对防守方来说，重点是检查 Diamond/Proxy 是否完成初始化、升级入口是否只允许可信角色调用，以及用户是否对不可信或治理薄弱的合约地址留下高额授权。

## 防御排查建议

- 确认所有 Diamond、Proxy、Upgradeable 合约在部署时完成初始化，并禁止外部账户重复初始化或接管 owner。
- 对初始化函数和升级函数增加明确访问控制，避免任何外部账户可以接管 owner 或升级逻辑。
- 检查 DiamondCut/upgrade 类入口是否只允许多签、Timelock 或明确治理角色调用。
- 盘点用户对业务合约、Diamond、Router 的 ERC20 allowance，尤其是已废弃或不再维护的合约地址。
- 对不再使用的合约执行 pause、revoke、迁移或前端提示，降低历史授权带来的风险。

## 附件说明

同目录下保留 `test.t.sol`，用于安全研究人员在本地 fork 环境中复核根因。测试文件使用新生成的 Foundry 地址和自研测试合约，不依赖历史攻击者合约。

## 安全说明

- 本 PoC 仅用于 fork 环境复现和防御研究。
- 不要把攻击交易广播到真实链上。
- 如果要判断当前是否仍存在风险，需要重新检查最新链上状态和合约权限状态。
