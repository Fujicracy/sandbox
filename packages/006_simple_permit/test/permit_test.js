const { ethers } = require("hardhat");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("Tests for TransferFrom with Permit", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployTestFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const Token = await hre.ethers.getContractFactory("MockToken");
    const token = await Token.deploy();

    const Processor = await hre.ethers.getContractFactory("PermitProcessor");
    const processor = await Processor.deploy(token.address);

    return { owner, otherAccount, token, processor };
  }

  it("Should revert when calling transferFrom with no permit", async function () {
    const { owner, otherAccount, token } = await loadFixture(deployTestFixture);
    const ownerBalance = await token.balanceOf(owner.address);
    const connectedToken = token.connect(otherAccount);
    await expect(connectedToken.transferFrom(owner.address, otherAccount.address, ownerBalance)).to.be.reverted;
    expect(await token.balanceOf(owner.address)).to.eq(ownerBalance);
    expect(await token.balanceOf(otherAccount.address)).to.eq(0);
  });

  it("Should revert when calling transferFrom with no permit", async function () {
    const { owner, otherAccount, token, processor } = await loadFixture(deployTestFixture);
    const ownerBalance = await token.balanceOf(owner.address);
    const deadline = ((await owner.provider.getBlock()).timestamp) + 60 * 60 // 1 hour to process permit;
    const message = await processor.permitMessage(
      owner.address,
      processor.address,
      ownerBalance,
      deadline
    );
    const ownerSigningKey = new ethers.utils.SigningKey('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');
    const ownerSignedMessage = await ownerSigningKey.signDigest(message);
    const { v, r, s } = ethers.utils.splitSignature(ownerSignedMessage);
    const connectedProcessor = processor.connect(otherAccount);
    await connectedProcessor.transferFromWithPermit(
      owner.address,
      processor.address,
      ownerBalance,
      deadline,
      v, r, s
    );
    expect(await token.balanceOf(otherAccount.address)).to.eq(ownerBalance);
  });


});
