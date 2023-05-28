import { ethers } from "hardhat";
import { Contract, ContractFactory, BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { router, token1, token2, token3 } from "./common/constant";

describe("SwapExamples", () => {
  let accounts: SignerWithAddress[] = [];
  let signer1: SignerWithAddress;

  let swapExamples: Contract;
  let token2Contract: Contract;
  let token1Contract: Contract;
  let token3Contract: Contract;

  let balance: BigNumber;

  before(async () => {
    [signer1] = await ethers.getSigners();
    accounts = [signer1];

    const SwapExamples: ContractFactory = await ethers.getContractFactory(
      "SwapExamples2"
    );
    swapExamples = await SwapExamples.deploy(router, token1, token2, token3);
    await swapExamples.deployed();

    // Check if the contract is stable coin
    if (token2 == "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2") {
      token2Contract = await ethers.getContractAt("IWETH", token2);
    } else {
      token2Contract = await ethers.getContractAt("IERC20", token2);
    }

    token1Contract = await ethers.getContractAt("IERC20", token1);
    token3Contract = await ethers.getContractAt("IERC20", token3);
  });

  it("swapExactInputSingle", async () => {
    const amountIn: bigint = 10n ** 18n; // 1
    const amountOutMinimum: number = 0;
    const fee1: number = 3000;
    const sqrtPriceLimitX96: number = 0;

    // Deposit token2Contract
    await token2Contract.deposit({ value: amountIn });
    await token2Contract.approve(swapExamples.address, amountIn);

    // Swap
    await swapExamples.swapExactInputSingle(
      token2Contract.address,
      token1Contract.address,
      amountIn,
      amountOutMinimum,
      fee1,
      sqrtPriceLimitX96
    );

    // format balance
    balance = await token1Contract.balanceOf(accounts[0].address);
    console.log(`token1 balance`, ethers.utils.formatEther(balance.toString()));
  });

  it("swapExactOutputSingle", async () => {
    const token2ContractAmountInMax: bigint = 10n ** 18n; // 1
    const token1ContractAmountOut: bigint = 100n * 10n ** 18n; // 100
    const fee1: number = 3000;
    const sqrtPriceLimitX96: number = 0;

    console.log(ethers.utils.formatEther(token2ContractAmountInMax.toString()));
    console.log(ethers.utils.formatEther(token1ContractAmountOut.toString()));

    // Deposit token2Contract
    await token2Contract.deposit({ value: token2ContractAmountInMax });
    await token2Contract.approve(
      swapExamples.address,
      token2ContractAmountInMax
    );

    // Swap
    await swapExamples.swapExactOutputSingle(
      token2Contract.address,
      token1Contract.address,
      token1ContractAmountOut,
      token2ContractAmountInMax,
      fee1,
      sqrtPriceLimitX96
    );

    // format balance
    balance = await token1Contract.balanceOf(accounts[0].address);
    console.log("token1 balance", ethers.utils.formatEther(balance.toString()));
  });

  it("swapExactInputMultihop", async () => {
    const amountIn = 10n ** 18n; // 1
    const fee1: number = 3000;
    const fee2: number = 100;

    // Deposit token2Contract
    await token2Contract.deposit({ value: amountIn });
    await token2Contract.approve(swapExamples.address, amountIn);

    // Swap
    await swapExamples.swapExactInputMultihop(
      token2Contract.address,
      token3Contract.address,
      token1Contract.address,
      amountIn,
      fee1,
      fee2
    );

    // format balance
    balance = await token1Contract.balanceOf(accounts[0].address);
    console.log("token1 balance", ethers.utils.formatEther(balance.toString()));
  });

    it("swapExactOutputMultihop", async () => {
      const token2ContractAmountInMax = 10n ** 18n; // 1
      const token1ContractAmountOut = 100n * 10n ** 18n; // 100
      const fee1: number = 100;
      const fee2: number = 3000;

      // Deposit token2Contract
      await token2Contract.deposit({ value: token2ContractAmountInMax });
      await token2Contract.approve(
        swapExamples.address,
        token2ContractAmountInMax
      );

      // Swap
      await swapExamples.swapExactOutputMultihop(
        token2Contract.address,
        token3Contract.address,
        token1Contract.address,
        token1ContractAmountOut,
        token2ContractAmountInMax,
        fee1,
        fee2
      );

      // format balance
      balance = await token1Contract.balanceOf(accounts[0].address);
      console.log("token1 balance", ethers.utils.formatEther(balance.toString()));
    });
});
