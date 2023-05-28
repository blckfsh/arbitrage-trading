import { ethers } from "hardhat";
import { Contract, ContractFactory, BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
  factory,
  router,
  token1,
  token2,
  token3,
  token4,
  weth,
  stable_decimals,
  erc20_decimals,
} from "./common/constant";

describe("Flashswap V3", () => {
  let accounts: SignerWithAddress[] = [];
  let signer1: SignerWithAddress;

  let swapExamples: Contract;
  let pairFlash: Contract;
  let token1Contract: Contract;
  let token2Contract: Contract;
  let token3Contract: Contract;
  let wethContract: Contract;

  let balance: BigNumber;
  let tx;

  before(async () => {
    [signer1] = await ethers.getSigners();
    accounts = [signer1];

    // deployed SwapExamples Contract
    const SwapExamples: ContractFactory = await ethers.getContractFactory(
      "SwapExamples2"
    );
    swapExamples = await SwapExamples.deploy(router, token1, token2, token3);
    await swapExamples.deployed();

    // deployed PairFlash Contract
    const PairFlash: ContractFactory = await ethers.getContractFactory(
      "PairFlash"
    );
    pairFlash = await PairFlash.deploy(
      swapExamples.address,
      factory,
      token1,
      token2,
      token3,
      token4,
      weth
    );
    await pairFlash.deployed();

    // Check if the contract is stable coin
    if (token1 == "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2") {
      token1Contract = await ethers.getContractAt("IWETH", token1);
    } else {
      token1Contract = await ethers.getContractAt("IERC20", token1);
    }

    if (token2 == "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2") {
      token2Contract = await ethers.getContractAt("IWETH", token2);
    } else {
      token2Contract = await ethers.getContractAt("IERC20", token2);
    }

    if (token3 == "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2") {
      token3Contract = await ethers.getContractAt("IWETH", token3);
    } else {
      token3Contract = await ethers.getContractAt("IERC20", token3);
    }

    wethContract = await ethers.getContractAt("IWETH", weth);
  });

  it("call flashswap", async () => {
    // get some WETH
    // check it out here: https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2#code
    // convert ETH to WETH
    const overrides = {
      value: ethers.utils.parseEther("200"),
      gasLimit: ethers.utils.hexlify(50000),
    };

    tx = await wethContract.connect(signer1).deposit(overrides);
    await tx.wait();

    // get some DAI
    // approve swaper to spend 2 WETH
    tx = await wethContract
      .connect(signer1)
      .approve(swapExamples.address, ethers.utils.parseEther("2"));
    await tx.wait();

    // swap 2 WETH -> _ DAI
    // CODE NOT NEEDED
    // tx = await swapExamples
    //   .connect(signer1)
    //   .swapTokenMax(
    //     token2Contract.address,
    //     token1Contract.address,
    //     ethers.utils.parseEther("2")
    //   );
    // await tx.wait();
    const amountIn: bigint = 10n ** 18n; // 1
    const amountOutMinimum: number = 0;
    const fee1: number = 3000;
    const sqrtPriceLimitX96: number = 0;

    tx = await swapExamples
      .connect(signer1)
      .swapExactInputSingle(
        weth,
        token1,
        amountIn,
        amountOutMinimum,
        fee1,
        sqrtPriceLimitX96
      );

    // const DAI_contract = new ethers.Contract(DAI_addr, erc_abi, signer);
    const balance_before = ethers.utils.formatEther(
      await token1Contract.balanceOf(signer1.address)
    );
    
    // transfer 1000 DAI to contract so that it can pay for the fees (bc we flash for a loss lol)
    // extra $$ (after fees) will be payed back
    tx = await token1Contract
      .connect(signer1)
      .transfer(pairFlash.address, ethers.utils.parseEther("200"));
      // .transfer(pairFlash.address, ethers.utils.parseEther(balance_before.toString()));
    await tx.wait();

    // FLASH SWAP
    const flash_params = {
      token0: token1Contract.address,
      token1: token2Contract.address,
      fee1: 500, // flash from the 0.05% fee pool
      amount0: ethers.utils.parseEther("1000"), // flash borrow this much DAI
      amount1: 0, // flash borrow 0 WETH
    };
    tx = await pairFlash.connect(signer1).initFlash(flash_params);
    await tx.wait();

    // 1 ether = 1 * 10^18 wei
    console.log("flash gas ether: ", tx.gasPrice.toNumber() / 1e18);

    const balance_after = ethers.utils.formatEther(
      await token1Contract.balanceOf(signer1.address)
    );
  
    console.log("Balance Before: %s", Number(balance_before));
    console.log("Balance After: %s", Number(balance_after));
    console.log(
      "Total Flash Change in Balance: %s",
      Number(balance_before) - Number(balance_after)
    );
  });
});
