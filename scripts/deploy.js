const hre = require("hardhat");
async function main() {
  const StreamingFactory = await hre.ethers.getContractFactory("NexusStreamingPayment");
  const streaming = await StreamingFactory.deploy();
  await streaming.deployed();
  console.log("Nexus Streaming Protocol deployed to:", streaming.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
