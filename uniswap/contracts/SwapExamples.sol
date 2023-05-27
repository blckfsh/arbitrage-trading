// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract SwapExamples {
    // NOTE: Does not work with SwapRouter02
    ISwapRouter public swapRouter;
    address public pool;

    address public adminRole;
    address public swapRole;

    address public token1;
    address public token2;
    address public token3;

    constructor(
        address _swapRouterAddress,
        address _token1Address,
        address _token2Address,
        address _token3Address
    ) {
        // Init roles
        adminRole = msg.sender;
        swapRole = msg.sender;

        // Init router
        swapRouter = ISwapRouter(_swapRouterAddress);

        // Init tokens
        token1 = _token1Address;
        token2 = _token2Address;
        token3 = _token3Address;
    }

    modifier onlyAdmin() {
        require(adminRole == msg.sender, "Not Admin");
        _;
    }

    modifier onlySwap() {
        require(swapRole == msg.sender, "Not Swap Role");
        _;
    }

    function setSwapRole(address _swapRoleAddress) external onlyAdmin {
        swapRole = _swapRoleAddress;
    }

    function initPool(address _factory, uint24 _fee) external onlyAdmin {
        address _pool = IUniswapV3Factory(_factory).getPool(
            token1,
            token2,
            _fee
        );
        require(_pool != address(0), "pool doesn't exist");

        pool = _pool;
    }

    function estimateAmountOut(
        address tokenIn,
        address tokenOut,
        uint128 amountIn,
        uint32 secondsAgo
    ) public view returns (uint256 amountOut) {
        require(
            tokenIn == token1 || tokenIn == token2 || tokenIn == token3,
            "invalid token"
        );

        // Need to specify the tokenOut
        // address tokenOut = tokenIn == token1 ? token2 : token1;

        // (int24 tick, ) = OracleLibrary.consult(pool, secondsAgo);

        // Code copied from OracleLibrary.sol, consult()
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        // int56 since tick * time = int24 * uint32
        // 56 = 24 + 32
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(
            secondsAgos
        );

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        // int56 / uint32 = int24
        int24 tick = int24(tickCumulativesDelta / secondsAgo);
        // Always round to negative infinity
        /*
        int doesn't round down when it is negative

        int56 a = -3
        -3 / 10 = -3.3333... so round down to -4
        but we get
        a / 10 = -3

        so if tickCumulativeDelta < 0 and division has remainder, then round
        down
        */
        if (
            tickCumulativesDelta < 0 && (tickCumulativesDelta % secondsAgo != 0)
        ) {
            tick--;
        }

        amountOut = OracleLibrary.getQuoteAtTick(
            tick,
            amountIn,
            tokenIn,
            tokenOut
        );
    }

    /// @notice Swaps a fixed amount of token2 for a maximum possible amount of token1
    function swapExactInputSingle(
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint24 fee1
        // uint256 desiredPriceMin,
        // uint256 desiredPriceMax
    ) external onlySwap returns (uint256 amountOut) {
        TransferHelper.safeTransferFrom(
            token2,
            msg.sender,
            address(this),
            amountIn
        );
        TransferHelper.safeApprove(token2, address(swapRouter), amountIn);

        // Calculate sqrtPriceLimitX96 based on desired price range
        // uint160 sqrtPriceLimitX96 = uint160(
        //     calculateSqrtPriceLimitX96(desiredPriceMin, desiredPriceMax)
        // );

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token2,
                tokenOut: token1,
                fee: fee1,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });
        amountOut = swapRouter.exactInputSingle(params);
    }

    /// @notice swaps a minimum possible amount of token2 for a fixed amount of token1.
    function swapExactOutputSingle(
        uint256 amountOut,
        uint256 amountInMaximum,
        uint24 fee1,
        uint160 sqrtPriceLimitX96
    ) external onlySwap returns (uint256 amountIn) {
        TransferHelper.safeTransferFrom(
            token2,
            msg.sender,
            address(this),
            amountInMaximum
        );
        TransferHelper.safeApprove(
            token2,
            address(swapRouter),
            amountInMaximum
        );

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
    function swapExactInputMultihop(
        uint256 amountIn,
        uint24 fee1,
        uint24 fee2
    ) external onlySwap returns (uint256 amountOut) {
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
    function swapExactOutputMultihop(
        uint256 amountOut,
        uint256 amountInMaximum,
        uint24 fee1,
        uint24 fee2
    ) external onlySwap returns (uint256 amountIn) {
        TransferHelper.safeTransferFrom(
            token2,
            msg.sender,
            address(this),
            amountInMaximum
        );
        TransferHelper.safeApprove(
            token2,
            address(swapRouter),
            amountInMaximum
        );

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

    function calculateSqrtPriceLimitX96(
        uint256 desiredPriceMin,
        uint256 desiredPriceMax
    ) internal pure returns (uint256) {
        require(desiredPriceMin < desiredPriceMax, "Invalid price range");

        // Calculate square root of desiredPriceMin and desiredPriceMax
        uint256 sqrtPriceLimitMin = sqrt(desiredPriceMin);
        uint256 sqrtPriceLimitMax = sqrt(desiredPriceMax);

        // Calculate the average of square root values
        uint256 sqrtPriceLimitX96 = (sqrtPriceLimitMin + sqrtPriceLimitMax) / 2;

        return sqrtPriceLimitX96;
    }

    // Helper function to calculate square root using Babylonian method
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) {
            return 0;
        }

        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }
}