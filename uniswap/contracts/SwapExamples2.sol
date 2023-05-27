// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract SwapExamples2 {
    // NOTE: Does not work with SwapRouter02
    ISwapRouter public swapRouter;

    address public token1; // DAI
    address public token2; // WETH
    address public token3; // USDC

    constructor(
        address swapRouterAddress_,
        address token1Address_,
        address token2Address_,
        address token3Address_
    ) {
        swapRouter = ISwapRouter(swapRouterAddress_);
        token1 = token1Address_;
        token2 = token2Address_;
        token3 = token3Address_;
    }

    /// @notice Swaps a fixed amount of token2 for a maximum possible amount of token1
    function swapExactInputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint256 amountOutMinimum_,
        uint24 fee1_,
        uint160 sqrtPriceLimitX96_
    ) external returns (uint256 amountOut_) {
        TransferHelper.safeTransferFrom(
            tokenIn_,
            msg.sender,
            address(this),
            amountIn_
        );
        TransferHelper.safeApprove(tokenIn_, address(swapRouter), amountIn_);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn_,
                tokenOut: tokenOut_,
                // pool fee 0.3% (3000)
                fee: fee1_,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn_,
                amountOutMinimum: amountOutMinimum_,
                // NOTE: In production, this value can be used to set the limit
                // for the price the swap will push the pool to,
                // which can help protect against price impact
                sqrtPriceLimitX96: sqrtPriceLimitX96_
                // NOTE: Research on this `sqrtPriceLimitX96` what could be the possible value
            });
        amountOut_ = swapRouter.exactInputSingle(params);
    }

    /// @notice swaps a minimum possible amount of token2 for a fixed amount of token1.
    function swapExactOutputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountOut_,
        uint256 amountInMaximum_,
        uint24 fee1_,
        uint160 sqrtPriceLimitX96_
    ) external returns (uint256 amountIn_) {
        TransferHelper.safeTransferFrom(
            tokenIn_,
            msg.sender,
            address(this),
            amountInMaximum_
        );
        TransferHelper.safeApprove(
            tokenIn_,
            address(swapRouter),
            amountInMaximum_
        );

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: tokenIn_,
                tokenOut: tokenOut_,
                fee: fee1_,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut_,
                amountInMaximum: amountInMaximum_,
                sqrtPriceLimitX96: sqrtPriceLimitX96_   
                // NOTE: Research on this `sqrtPriceLimitX96` what could be the possible value
            });

        amountIn_ = swapRouter.exactOutputSingle(params);

        if (amountIn_ < amountInMaximum_) {
            // Reset approval on router
            TransferHelper.safeApprove(tokenIn_, address(swapRouter), 0);
            // Refund token2 to user
            TransferHelper.safeTransfer(
                tokenIn_,
                msg.sender,
                amountInMaximum_ - amountIn_
            );
        }
    }

    /// @notice swapInputMultiplePools swaps a fixed amount of token2 for a maximum possible amount of token1
    /// swap token2 --> token3 --> token1
    function swapExactInputMultihop(
        address tokenIn_,
        address tokenOut1_,
        address tokenOut2_,
        uint256 amountIn_,
        uint24 fee1_,
        uint24 fee2_
    ) external returns (uint256 amountOut_) {
        TransferHelper.safeTransferFrom(
            tokenIn_,
            msg.sender,
            address(this),
            amountIn_
        );
        TransferHelper.safeApprove(tokenIn_, address(swapRouter), amountIn_);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: abi.encodePacked(
                    tokenIn_,
                    uint24(fee1_),
                    tokenOut1_,
                    uint24(fee2_),
                    tokenOut2_
                ),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn_,
                amountOutMinimum: 0
                // NOTE: Modify to use an on-chain price oracle for the amountOutMin
            });
        amountOut_ = swapRouter.exactInput(params);
    }

    /// @notice swapExactOutputMultihop swaps a minimum possible amount of token2 for a fixed amount of token3
    /// swap token2 --> token3 --> token1
    function swapExactOutputMultihop(
        address tokenIn_,
        address tokenOut1_,
        address tokenOut2_,
        uint256 amountOut_,
        uint256 amountInMaximum_,
        uint24 fee1_,
        uint24 fee2_
    ) external returns (uint256 amountIn_) {
        TransferHelper.safeTransferFrom(
            tokenIn_,
            msg.sender,
            address(this),
            amountInMaximum_
        );
        TransferHelper.safeApprove(
            tokenIn_,
            address(swapRouter),
            amountInMaximum_
        );

        // The parameter path is encoded as (tokenOut, fee, tokenIn/tokenOut, fee, tokenIn)
        ISwapRouter.ExactOutputParams memory params = ISwapRouter
            .ExactOutputParams({
                path: abi.encodePacked(
                    tokenOut2_,
                    uint24(fee1_),
                    tokenOut1_,
                    uint24(fee2_),
                    tokenIn_
                ),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut_,
                amountInMaximum: amountInMaximum_
            });

        amountIn_ = swapRouter.exactOutput(params);
        if (amountIn_ < amountInMaximum_) {
            TransferHelper.safeApprove(tokenIn_, address(swapRouter), 0);
            TransferHelper.safeTransferFrom(
                tokenIn_,
                address(this),
                msg.sender,
                amountInMaximum_ - amountIn_
            );
        }
    }
}
