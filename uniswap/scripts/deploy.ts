require("dotenv").config();
import { ethers } from "hardhat";

async function main() {
    const SSContract = await ethers.getContractFactory("SingleSwap");
    const swap = await SSContract.deploy();
    await swap.deployed();

    console.log("address: ", swap.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
