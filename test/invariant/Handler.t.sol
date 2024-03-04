// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool tSwapPool;

    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("lp");
    address swapper = makeAddr("swapper");

    // Ghost Variables
    // The reason it is called `Ghost` variables is
    // They don't exist in the actual contract, they only exist in our handler
    int256 public startingX;
    int256 public startingY;

    int256 public expectedDeltaX;
    int256 public expectedDeltaY;
    int256 public actualDeltaX;
    int256 public actualDeltaY;

    constructor(TSwapPool _tSwapPool) {
        tSwapPool = _tSwapPool;
        poolToken = ERC20Mock(_tSwapPool.getPoolToken());
        weth = ERC20Mock(_tSwapPool.getWeth());
    }

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        uint256 minWeth = tSwapPool.getMinimumWethDepositAmount();
        outputWeth = bound(outputWeth, minWeth, weth.balanceOf(address(tSwapPool)));

        // we don't want to swap entire balance
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

        // actual
        uint256 endingY = weth.balanceOf(address(tSwapPool));
        uint256 endingX = poolToken.balanceOf(address(tSwapPool));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }

    function deposit(uint256 wethAmount) public {
        // let's make sure `wethAmount` is reasonable
        // to avoid weird overflows
        uint256 minWeth = tSwapPool.getMinimumWethDepositAmount();
        wethAmount = bound(wethAmount, minWeth, weth.balanceOf(address(tSwapPool)));

        startingY = int256(weth.balanceOf(address(tSwapPool)));
        startingX = int256(poolToken.balanceOf(address(tSwapPool)));

        expectedDeltaY = int256(wethAmount);
        expectedDeltaX = int256(wethAmount);

        vm.startPrank(liquidityProvider);

        // let's give token balance to the `liquidityProvider`
        weth.mint(liquidityProvider, wethAmount);
        poolToken.mint(liquidityProvider, uint256(expectedDeltaX));

        // approve
        weth.approve(address(tSwapPool), type(uint256).max);
        poolToken.approve(address(tSwapPool), type(uint256).max);

        // deposit
        tSwapPool.deposit(wethAmount, 0, uint256(expectedDeltaX), uint64(block.timestamp));
        // `minimumLiquidityTokensToMint` dosen't matter to us therfore => `0`

        vm.stopPrank();

        // actual
        uint256 endingY = weth.balanceOf(address(tSwapPool));
        uint256 endingX = poolToken.balanceOf(address(tSwapPool));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }
}
