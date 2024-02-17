// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool tSwapPool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    // Ghost Variables
    // The reason it is called ghost variables is, they don't exist in the actual contract.
    // They only exist in our Handler.
    int256 startingY;
    int256 startingX;

    int256 public expectedDeltaY;
    int256 public expectedDeltaX;
    int256 public actualDeltaY;
    int256 public actualDeltaX;

    address liquidityProvider = makeAddr("lp");
    address swapper = makeAddr("swapper");

    constructor(TSwapPool _tSwapPool) {
        tSwapPool = _tSwapPool;
        weth = ERC20Mock(tSwapPool.getWeth());
        poolToken = ERC20Mock(tSwapPool.getPoolToken());
    }

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        uint256 minWeth = tSwapPool.getMinimumWethDepositAmount();
        outputWeth = bound(outputWeth, minWeth, weth.balanceOf(address(tSwapPool)));
        if (outputWeth >= weth.balanceOf(address(tSwapPool))) {
            return;
        }

        uint256 poolTokenAmount = tSwapPool.getInputAmountBasedOnOutput(
            outputWeth, poolToken.balanceOf(address(tSwapPool)), weth.balanceOf(address(tSwapPool))
        );

        if (poolTokenAmount > type(uint64).max) {
            return;
        }

        startingY = int256(weth.balanceOf(address(tSwapPool)));
        startingX = int256(poolToken.balanceOf(address(tSwapPool)));

        expectedDeltaY = int256(-1) * int256(outputWeth);
        expectedDeltaX = int256(poolTokenAmount);

        if (poolToken.balanceOf(swapper) < poolTokenAmount) {
            poolToken.mint(swapper, poolTokenAmount - poolToken.balanceOf(swapper) + 1);
        }

        vm.startPrank(swapper);
        poolToken.approve(address(tSwapPool), type(uint256).max);
        tSwapPool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();

        uint256 endingY = weth.balanceOf(address(tSwapPool));
        uint256 endingX = poolToken.balanceOf(address(tSwapPool));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }

    function deposit(uint256 wethAmount) public {
        // let's make sure it's a "reasonable" amount
        // avoid weird overflow errors
        uint256 minWeth = tSwapPool.getMinimumWethDepositAmount();
        wethAmount = bound(wethAmount, minWeth, type(uint64).max);

        startingY = int256(weth.balanceOf(address(tSwapPool)));
        startingX = int256(poolToken.balanceOf(address(tSwapPool)));

        expectedDeltaY = int256(wethAmount);
        expectedDeltaX = int256(tSwapPool.getPoolTokensToDepositBasedOnWeth(wethAmount));

        // deposit
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmount);
        poolToken.mint(liquidityProvider, uint256(expectedDeltaX));
        weth.approve(address(tSwapPool), type(uint256).max);
        poolToken.approve(address(tSwapPool), type(uint256).max);

        tSwapPool.deposit(wethAmount, 0, uint256(expectedDeltaX), uint64(block.timestamp));
        vm.stopPrank();

        uint256 endingY = weth.balanceOf(address(tSwapPool));
        uint256 endingX = poolToken.balanceOf(address(tSwapPool));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }
}
