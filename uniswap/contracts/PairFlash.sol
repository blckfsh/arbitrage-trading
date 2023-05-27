// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "hardhat/console.sol";
import { SwapExamples2 } from "contracts/SwapExamples2.sol";

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";

import "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//fee1 is the fee of the pool from the initial borrow
//fee2 is the fee of the first pool to arb from
//fee3 is the fee of the second pool to arb from
struct FlashParams {
    address token0;
    address token1;
    uint24 fee1;
    uint256 amount0;
    uint256 amount1;
}
// fee2 and fee3 are the two other fees associated with the two other pools of token0 and token1
struct FlashCallbackData {
    uint256 amount0;
    uint256 amount1;
    address payer;
    PoolAddress.PoolKey poolKey;
}

/// @title Flash contract implementation
/// @notice An example contract using the Uniswap V3 flash function
contract PairFlash is IUniswapV3FlashCallback, PeripheryImmutableState, PeripheryPayments {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    SwapExamples2 public immutable swaper;

    constructor(
        SwapExamples2 swapAddress_,
        address factory_,
        address WETH9_
    ) PeripheryImmutableState(factory_, WETH9_) {
        swaper = swapAddress_;
    }

    // COMMENTED: NOT NEEDED AT THE MOMENT
    // function transfer_wrapper(address token1_, address token2_, uint amount_swap_) private returns (uint amount_out_){
    //     TransferHelper.safeApprove(token1_, address(swaper), amount_swap_); // approve swaper to spend token 
    //     amount_out_ = swaper.swapTokenMax(token1_, token2_, amount_swap_); // swap between tokens with uniswap         
    // }

    function doApprove(address token_, uint256 amount_) private {
        TransferHelper.safeApprove(token_, address(swaper), amount_); // approve swaper to spend token 
    }

    /// @param fee0 The fee from calling flash for token0
    /// @param fee1 The fee from calling flash for token1
    /// @param data The data needed in the callback passed as FlashCallbackData from `initFlash`
    /// @notice implements the callback called from flash
    /// @dev fails if the flash is not profitable, meaning the amountOut from the flash is less than the amount borrowed
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        address token0 = decoded.poolKey.token0; // DAI 
        address token1 = decoded.poolKey.token1; // WETH 

        console.log("--- flash swap start ---");
        log_balances();

        uint amount_swap = decoded.amount0; // flash swap amount DAI 

        // DAI -> WETH
        doApprove(DAI, amount_swap);
        uint swap_out = swaper.swapExactInputSingle(DAI, WETH, amount_swap, 0, 3000, 0);
        console.log("--- after DAI -> WETH swap ---");
        log_balances();

        // WETH -> USDC -> DAI
        doApprove(WETH, swap_out);
        swaper.swapExactInputMultihop(WETH, USDC, DAI, swap_out, 3000, 100);
        console.log("--- after WETH -> USDC -> DAI swap ---");
        log_balances();

        // // DAI -> WETH
        // uint swap_out = transfer_wrapper(DAI, WETH, amount_swap);
        // console.log("--- after DAI -> WETH swap ---");
        // log_balances();
                
        // // WETH -> USDC 
        // swap_out = transfer_wrapper(WETH, USDC, swap_out);
        // console.log("--- after WETH -> USDC swap ---");
        // log_balances();

        // // USDC -> DAI 
        // swap_out = transfer_wrapper(USDC, DAI, swap_out);
        // console.log("--- after USDC -> DAI swap ---");
        // log_balances();
        
        // compute amount to pay back to pool 
        // (amount loaned) + fee
        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1);

        // pay back pool the loan 
        // note: msg.sender == pool to pay back 
        if (amount0Owed > 0) pay(token0, address(this), msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(token1, address(this), msg.sender, amount1Owed);
    }

    /// @param params The parameters necessary for flash and the callback, passed in as FlashParams
    /// @notice Calls the pools flash function with data needed in `uniswapV3FlashCallback`
    function initFlash(FlashParams memory params) external {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee1});
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));

        console.log("--- init balances ---");
        log_balances();

        // recipient of borrowed amounts (should be (this) contract)
        // amount of token0 requested to borrow
        // amount of token1 requested to borrow
        // callback data encoded 
        pool.flash(
            address(this),
            params.amount0,
            params.amount1,
            abi.encode(
                FlashCallbackData({
                    amount0: params.amount0,
                    amount1: params.amount1,
                    payer: msg.sender,
                    poolKey: poolKey
                })
            )
        );

        // send the rest of the balance back to the sender         
        IERC20(DAI).transfer(msg.sender, IERC20(DAI).balanceOf(address(this)));
        IERC20(WETH).transfer(msg.sender, IERC20(WETH).balanceOf(address(this)));
        IERC20(USDC).transfer(msg.sender, IERC20(USDC).balanceOf(address(this)));

        console.log("--- empty contract ---");
        log_balances();

        console.log("flash success!");
    }

    function log_balances() view private {
        uint balance_weth = IERC20(WETH).balanceOf(address(this));
        uint balance_dai = IERC20(DAI).balanceOf(address(this));
        uint balance_usdc = IERC20(USDC).balanceOf(address(this));
        // DAI is in scale 1 * 10^18 wei = 1 ether
        // USDC is in scale 1 * 10^6
        // since solidity doesn't print floats we must hack >:)
        console.log("WETH: %s.%s", balance_weth / 1e18, balance_weth - (balance_weth / 1e18) * 1e18); 
        console.log("DAI: %s.%s", balance_dai / 1e18, balance_dai - (balance_dai / 1e18) * 1e18);
        console.log("USDC: %s.%s", balance_usdc / 1e6, balance_usdc - (balance_usdc / 1e6) * 1e6);
    }
}