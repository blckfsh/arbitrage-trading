// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract SwapExamples {
    // NOTE: Does not work with SwapRouter02
    ISwapRouter public swapRouter;

    address public token1; // DAI
    address public token2; // token29
    address public token3; // USDC 

    constructor(address _swapRouterAddress, address _token1Address, address _token2Address, address _token3Address) {
        swapRouter = ISwapRouter(_swapRouterAddress);
        token1 = _token1Address;
        token2 = _token2Address;
        token3 = _token3Address;
    }

    /// @notice Swaps a fixed amount of token2 for a maximum possible amount of token1
    function swapExactInputSingle(uint amountIn, uint amountOutMinimum, uint24 fee1, uint160 sqrtPriceLimitX96)
        external
        returns (uint amountOut)
    {
        TransferHelper.safeTransferFrom(
            token2,
            msg.sender,
            address(this),
            amountIn
        );
        TransferHelper.safeApprove(token2, address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
        .ExactInputSingleParams({
            tokenIn: token2,
            tokenOut: token1,
            // pool fee 0.3% (3000)
            fee: fee1,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            // NOTE: In production, this value can be used to set the limit
            // for the price the swap will push the pool to,
            // which can help protect against price impact
            sqrtPriceLimitX96: sqrtPriceLimitX96
            // NOTE: Research on this `sqrtPriceLimitX96` what could be the possible value
        });
        amountOut = swapRouter.exactInputSingle(params);
    }

    /// @notice swaps a minimum possible amount of token2 for a fixed amount of token1.
    function swapExactOutputSingle(uint amountOut, uint amountInMaximum, uint24 fee1, uint160 sqrtPriceLimitX96)
        external
        returns (uint amountIn)
    {
        TransferHelper.safeTransferFrom(
            token2,
            msg.sender,
            address(this),
            amountInMaximum
        );
        TransferHelper.safeApprove(token2, address(swapRouter), amountInMaximum);

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: token2,
                tokenOut: token1,
                fee: fee1,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: sqrtPriceLimitX96
                // NOTE: Research on this `sqrtPriceLimitX96` what could be the possible value
            });

        amountIn = swapRouter.exactOutputSingle(params);

        if (amountIn < amountInMaximum) {
            // Reset approval on router
            TransferHelper.safeApprove(token2, address(swapRouter), 0);
            // Refund token2 to user
            TransferHelper.safeTransfer(
                token2,
                msg.sender,
                amountInMaximum - amountIn
            );
        }
    }

    /// @notice swapInputMultiplePools swaps a fixed amount of token2 for a maximum possible amount of token1
    /// swap token2 --> token3 --> token1
    function swapExactInputMultihop(uint amountIn, uint24 fee1, uint24 fee2)
        external
        returns (uint amountOut)
    {
        TransferHelper.safeTransferFrom(
            token2,
            msg.sender,
            address(this),
            amountIn
        );
        TransferHelper.safeApprove(token2, address(swapRouter), amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: abi.encodePacked(
                    token2,
                    uint24(fee1),
                    token3,
                    uint24(fee2),
                    token1
                ),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0
                // NOTE: Modify to use an on-chain price oracle for the amountOutMin
            });
        amountOut = swapRouter.exactInput(params);
    }

    /// @notice swapExactOutputMultihop swaps a minimum possible amount of token2 for a fixed amount of token3
    /// swap token2 --> token3 --> token1
    function swapExactOutputMultihop(uint amountOut, uint amountInMaximum, uint24 fee1, uint24 fee2)
        external
        returns (uint amountIn)
    {
        TransferHelper.safeTransferFrom(
            token2,
            msg.sender,
            address(this),
            amountInMaximum
        );
        TransferHelper.safeApprove(token2, address(swapRouter), amountInMaximum);

        // The parameter path is encoded as (tokenOut, fee, tokenIn/tokenOut, fee, tokenIn)
        ISwapRouter.ExactOutputParams memory params = ISwapRouter
            .ExactOutputParams({
                path: abi.encodePacked(
                    token1,
                    uint24(fee1),
                    token3,
                    uint24(fee2),
                    token2
                ),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum
            });

        amountIn = swapRouter.exactOutput(params);
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(token2, address(swapRouter), 0);
            TransferHelper.safeTransferFrom(
                token2,
                address(this),
                msg.sender,
                amountInMaximum - amountIn
            );
        }
    }
}