const hre = require("hardhat");

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  // deploy CD NFT Contract
  const nftContract = await hre.ethers.deployContract("CryptoDevsNFT");
  await nftContract.waitForDeployment();
  console.log("CryptoDevsNFT deployed to:", nftContract.target);

  // deploy Fake Marketplace contract
  const fakeNftMarketplaceContract = await hre.ethers.deployContract(
    "FakeNFTMarketplace"
  );
  await fakeNftMarketplaceContract.waitForDeployment();
  console.log(
    "FakeNFTMarketplace deployed to:",
    fakeNftMarketplaceContract.target
  );

  // deploy DAO contract
  const daoContract = await hre.ethers.deployContract("CryptoDevsDAO", [
    fakeNftMarketplaceContract.target,
    nftContract.target,
  ]);
  await daoContract.waitForDeployment();
  console.log("CryptoDevsDAO deployed to:", daoContract.target);

  // sleep for 30 seconds to let Etherscan catch up with deployments
  await sleep(30 * 1000);

  // verify CD NFT contract
  await hre.run("verify:verify", {
    address: nftContract.target,
    constructorArguments: [],
  });

  // verify Fake Marketplace contract
  await hre.run("verify:verify", {
    address: fakeNftMarketplaceContract.target,
    constructorArguments: [],
  });

  // verify DAO contract
  await hre.run("verify:verify", {
    address: daoContract.target,
    constructorArguments: [
      fakeNftMarketplaceContract.target,
      nftContract.target,
    ],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
