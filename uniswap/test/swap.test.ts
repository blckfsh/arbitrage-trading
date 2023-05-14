import { ethers } from "hardhat";
import { Contract, ContractFactory, BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const WETH9 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

describe("SwapExamples", () => {
  let accounts: SignerWithAddress[] = [];
  let signer1: SignerWithAddress;

  let swapExamples: Contract;
  let weth: Contract;
  let dai: Contract;
  let usdc: Contract;

  let balance: BigNumber;

  before(async () => {
    [signer1] = await ethers.getSigners();
    accounts = [signer1];

    const SwapExamples: ContractFactory = await ethers.getContractFactory(
      "SwapExamples"
    );
    swapExamples = await SwapExamples.deploy();
    await swapExamples.deployed();

    weth = await ethers.getContractAt("IWETH", WETH9);
    dai = await ethers.getContractAt("IERC20", DAI);
    usdc = await ethers.getContractAt("IERC20", USDC);
  });

  it("swapExactInputSingle", async () => {
    const amountIn = 10n ** 18n;

    // Deposit WETH
    await weth.deposit({ value: amountIn });
    await weth.approve(swapExamples.address, amountIn);

    // Swap
    await swapExamples.swapExactInputSingle(amountIn);

    // format balance
    balance = await dai.balanceOf(accounts[0].address);

    console.log("DAI balance", ethers.utils.formatEther(balance.toString()));
  });

  it("swapExactOutputSingle", async () => {
    const wethAmountInMax = 10n ** 18n;
    const daiAmountOut = 100n * 10n ** 18n;

    // Deposit WETH
    await weth.deposit({ value: wethAmountInMax });
    await weth.approve(swapExamples.address, wethAmountInMax);

    // Swap
    await swapExamples.swapExactOutputSingle(daiAmountOut, wethAmountInMax);

    // format balance
    balance = await dai.balanceOf(accounts[0].address);

    console.log("DAI balance", ethers.utils.formatEther(balance.toString()));
  });

  it("swapExactInputMultihop", async () => {
    const amountIn = 10n ** 18n;

    // Deposit WETH
    await weth.deposit({ value: amountIn });
    await weth.approve(swapExamples.address, amountIn);

    // Swap
    await swapExamples.swapExactInputMultihop(amountIn);

    // format balance
    balance = await dai.balanceOf(accounts[0].address);

    console.log("DAI balance", ethers.utils.formatEther(balance.toString()));
  });

  it("swapExactOutputMultihop", async () => {
    const wethAmountInMax = 10n ** 18n;
    const daiAmountOut = 100n * 10n ** 18n;

    // Deposit WETH
    await weth.deposit({ value: wethAmountInMax });
    await weth.approve(swapExamples.address, wethAmountInMax);

    // Swap
    await swapExamples.swapExactOutputMultihop(daiAmountOut, wethAmountInMax);

    // format balance
    balance = await dai.balanceOf(accounts[0].address);

    console.log("DAI balance", ethers.utils.formatEther(balance.toString()));
  });
});
