require("dotenv").config();
const { ethers } = require("hardhat");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

if (!process.env.PRIVATE_KEY_HARDHAT_TEST_SIGNER) {
  throw "Please set PRIVATE_KEY_HARDHAT_TEST_SIGNER in .env";
} 

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

  it("Test No. 1: Should revert when calling transferFrom with no permit", async function () {
    const { owner, otherAccount, token } = await loadFixture(deployTestFixture);
    const ownerBalance = await token.balanceOf(owner.address);
    const connectedToken = token.connect(otherAccount);
    await expect(connectedToken.transferFrom(owner.address, otherAccount.address, ownerBalance)).to.be.reverted;
    expect(await token.balanceOf(owner.address)).to.eq(ownerBalance);
    expect(await token.balanceOf(otherAccount.address)).to.eq(0);
  });

  it("Test No. 2: Succesfully execute transferFrom with permit - using ethersjs 'signDigest' method of a SigningKey class.", async function () {
    const { owner, otherAccount, token, processor } = await loadFixture(deployTestFixture);
    const ownerBalance = await token.balanceOf(owner.address);
    const deadline = ((await owner.provider.getBlock()).timestamp) + 60 * 60 // 1 hour to process permit;

    // Using Etherjs 'signDigest' method of ethers.SigningKey class
    // The goal is to obtain the v,r,s values.
    // This method will probably not be used in production front-end.
    const messageDigest = await processor.getPermitDigest(
      owner.address,
      processor.address,
      ownerBalance,
      deadline
    );
    const ownerSigningKey = new ethers.utils.SigningKey(process.env.PRIVATE_KEY_HARDHAT_TEST_SIGNER);
    const ownerSignedDigest = await ownerSigningKey.signDigest(messageDigest);
    const { v, r, s } = ethers.utils.splitSignature(ownerSignedDigest);

    const connectedProcessor = processor.connect(otherAccount);
    await connectedProcessor.transferFromWithPermit(
      owner.address,
      processor.address,
      ownerBalance,
      deadline,
      v, r, s
    );
    expect(await token.balanceOf(otherAccount.address)).to.eq(ownerBalance);
    expect(await token.balanceOf(owner.address)).to.eq(0);
  });

  it("Test No. 3: Succesfully execute transferFrom with permit - using ethersjs '_signTypedData' method of a Signer class", async function () {
    const { owner, otherAccount, token, processor } = await loadFixture(deployTestFixture);
    const ownerBalance = await token.balanceOf(owner.address);
    const deadline = ((await owner.provider.getBlock()).timestamp) + 60 * 60 // 1 hour to process permit;

    // Using Etherjs _signTypedData method of ethers.Signer class
    // The goal is to obtain the v,r,s values.
    // This method is in similarity on how browser wallets will process signature.
    const messageDigest = await processor.getPermitDigest(
      owner.address,
      processor.address,
      ownerBalance,
      deadline
    );
    const ownerSigningKey = new ethers.utils.SigningKey(process.env.PRIVATE_KEY_HARDHAT_TEST_SIGNER);
    const ownerSignedDigest = await ownerSigningKey.signDigest(messageDigest);
    const { v, r, s } = ethers.utils.splitSignature(ownerSignedDigest);

    const connectedProcessor = processor.connect(otherAccount);
    await connectedProcessor.transferFromWithPermit(
      owner.address,
      processor.address,
      ownerBalance,
      deadline,
      v, r, s
    );
    expect(await token.balanceOf(otherAccount.address)).to.eq(ownerBalance);
    expect(await token.balanceOf(owner.address)).to.eq(0);
  });


});
