const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe('VoxelVerseMiners', function () {
  let prospect, voxelversestone, voxelversewood, claimtoken, distributionpool, prospectpowerbank, referrers, voxelversewindmill, pickaxes, voxelversebitcoinminer, voxelverseskaleminer, owner;

  before(async () => {
    [owner, addr1] = await ethers.getSigners();
    const Prospect = await ethers.getContractFactory('Prospect');
    prospect = await Prospect.deploy();
    console.log("Prospect contract deployed to:", prospect.address);

    const VoxelVerseStone = await ethers.getContractFactory('VoxelVerseStone');
    voxelversestone = await VoxelVerseStone.deploy();
    console.log("Stone contract deployed to:", voxelversestone.address);

    const VoxelVerseWood = await ethers.getContractFactory('VoxelVerseWood');
    voxelversewood = await VoxelVerseWood.deploy();
    console.log("Wood contract deployed to:", voxelversewood.address);

    const ClaimToken = await ethers.getContractFactory('ClaimToken');
    claimtoken = await ClaimToken.deploy();
    console.log("Claim contract deployed to:", claimtoken.address);

    const DistributionPool = await ethers.getContractFactory('DistributionPool');
    distributionpool = await DistributionPool.deploy();
    console.log("Distribution Pool contract deployed to:", distributionpool.address);

    const ProspectPowerBank = await ethers.getContractFactory('ProspectPowerBank');
    prospectpowerbank = await ProspectPowerBank.deploy();
    console.log("Prospect Power Bank contract deployed to:", prospectpowerbank.address);

    const Referrers = await ethers.getContractFactory('Referrers');
    referrers = await Referrers.deploy();
    console.log("Referrers contract deployed to:", referrers.address);

    const VoxelVerseWindmill = await ethers.getContractFactory('VoxelVerseWindmill');
    voxelversewindmill = await VoxelVerseWindmill.deploy();
    console.log("Windmill contract deployed to:", voxelversewindmill.address);

    const Pickaxes = await ethers.getContractFactory('Pickaxes');
    pickaxes = await Pickaxes.deploy();
    console.log("Pickaxes contract deployed to:", pickaxes.address);

    const VoxelVerseBitcoinMiner = await ethers.getContractFactory('VoxelVerseBitcoinMiner');
    voxelversebitcoinminer = await VoxelVerseBitcoinMiner.deploy();
    console.log("Bitcoin Miner contract deployed to:", voxelversebitcoinminer.address);

    const VoxelVerseSkaleMiner = await ethers.getContractFactory('VoxelVerseSkaleMiner');
    voxelverseskaleminer = await VoxelVerseSkaleMiner.deploy();
    console.log("Skale Miner contract deployed to:", voxelverseskaleminer.address);

    const boostRate = ethers.utils.parseUnits("0.02", "ether");  // 0.02 ether in wei
    const minerPrice = ethers.utils.parseUnits("200", "ether");  // 200 ether in wei
    const minerDiscountPrice = ethers.utils.parseUnits("190", "ether");  // 190 ether in wei
    const burnAmount = ethers.utils.parseUnits("2", "ether");    // 2 ether in wei
    const approvalAmount = ethers.utils.parseUnits("50000", "ether"); // 50000 ether in wei
    const capRate = ethers.utils.parseUnits("0.7", "ether"); // 0.7 ether in wei
    const lowCap = ethers.utils.parseUnits("50", "ether"); // 50 ether in wei
    const medCap = ethers.utils.parseUnits("100", "ether"); // 100 ether in wei
    const highCap = ethers.utils.parseUnits("150", "ether"); // 150 ether in wei
    const premCap = ethers.utils.parseUnits("500", "ether"); // 500 ether in wei
    const claimLowCap = ethers.utils.parseUnits("1", "ether"); // 1 ether in wei
    const claimMedCap = ethers.utils.parseUnits("2", "ether"); // 2 ether in wei
    const claimHighCap = ethers.utils.parseUnits("3", "ether"); // 3 ether in wei
    const claimPremCap = ethers.utils.parseUnits("10", "ether"); // 10 ether in wei
    const bool = 0x00;

    await claimtoken.setMinterContract(referrers.address);
    await voxelversebitcoinminer.initializeDp(distributionpool.address);
    await voxelversebitcoinminer.initializeWm(voxelversewindmill.address);
    await voxelversebitcoinminer.addCurrency(prospect.address, "Prospect");
    await voxelversebitcoinminer.setRate(0,1);
    await voxelversebitcoinminer.addCurrency(claimtoken.address, "Claim");
    await voxelversebitcoinminer.setRate(1,1);
    await voxelversebitcoinminer.setTruBhsh(140);
    await voxelversebitcoinminer.setDailyBlocks(17000);
    await voxelversebitcoinminer.setBtcBoostRate(boostRate);
    await voxelversebitcoinminer.setBTCMinerPrice(minerPrice);
    await voxelversebitcoinminer.setBTCMinerDiscountedPrice(minerDiscountPrice);
    await voxelversebitcoinminer.setBurnAmount(burnAmount);
    await voxelverseskaleminer.initializeDp(distributionpool.address);
    await voxelverseskaleminer.initializeWm(voxelversewindmill.address);
    await voxelverseskaleminer.addCurrency(prospect.address, "Prospect");
    await voxelverseskaleminer.setRate(0,1);
    await voxelverseskaleminer.addCurrency(claimtoken.address, "Claim");
    await voxelverseskaleminer.setRate(1,1);
    await voxelverseskaleminer.setTruSklhsh(100);
    await voxelverseskaleminer.setDailyBlocks(17000);
    await voxelverseskaleminer.setSklBoostRate(boostRate);
    await voxelverseskaleminer.setSKLMinerPrice(minerPrice);
    await voxelverseskaleminer.setSKLMinerDiscountedPrice(minerDiscountPrice);
    await voxelverseskaleminer.setBurnAmount(burnAmount);
    await distributionpool.allowContract(voxelversebitcoinminer.address);
    await distributionpool.allowContract(voxelverseskaleminer.address);
    await distributionpool.addCurrency(prospect.address);
    await distributionpool.setRate(0,1);
    await prospectpowerbank.allowContract(pickaxes.address);
    await prospectpowerbank.addCurrency(prospect.address);
    await prospectpowerbank.setRate(0,1);
    await referrers.initializeCm(claimtoken.address);
    await referrers.initializeBm(voxelversebitcoinminer.address);
    await referrers.initializeSm(voxelverseskaleminer.address);
    await prospect.approve(distributionpool.address, approvalAmount);
    await prospect.approve(voxelversebitcoinminer.address, approvalAmount);
    await prospect.approve(voxelverseskaleminer.address, approvalAmount);
    await prospect.approve(pickaxes.address, approvalAmount);
    await prospect.approve(prospectpowerbank.address, approvalAmount);
    await prospect.approve(voxelversewindmill.address, approvalAmount);
    await claimtoken.approve(voxelversebitcoinminer.address, approvalAmount);
    await claimtoken.approve(voxelverseskaleminer.address, approvalAmount);
    await claimtoken.approve(voxelversewindmill.address, approvalAmount);
    await voxelversewindmill.addCurrency(prospect.address, "Prospect");
    await voxelversewindmill.setRate(0,1);
    await voxelversewindmill.addCurrency(claimtoken.address, "Claim");
    await voxelversewindmill.setRate(1,1);
    await voxelversewindmill.setWindmillCapRate(capRate);
    await voxelversewindmill.initializeWd(voxelversewood.address);
    await voxelversewindmill.initializeSt(voxelversestone.address);
    await voxelversewood.setApprovalForAll(voxelversewindmill.address, bool);
    await voxelversestone.setApprovalForAll(voxelversewindmill.address, bool);
    // secondary account
    await prospect.connect(addr1).approve(voxelversebitcoinminer.address, approvalAmount);
    await prospect.connect(addr1).approve(voxelverseskaleminer.address, approvalAmount);
    await prospect.connect(addr1).approve(voxelversewindmill.address, approvalAmount);
    await prospect.connect(addr1).approve(pickaxes.address, approvalAmount);
    await prospect.connect(addr1).approve(prospectpowerbank.address, approvalAmount);


  });

  async function advanceBlocks(numBlocks) {
    for (let i = 0; i < numBlocks; i++) {
      await network.provider.send('evm_mine');
    }
  }

  it('Should return set Bitcoin Mining Data', async function () {
    const dailyBlocksData = await voxelversebitcoinminer.dailyBlocks();
    console.log(dailyBlocksData);
    const truBhshData = await voxelversebitcoinminer.truBhsh();
    console.log(truBhshData);
    const boostRateData = await voxelversebitcoinminer.btcBoostRate();
    console.log(boostRateData);
    const btcMinerPriceData = await voxelversebitcoinminer.btcMinerPrice();
    console.log(btcMinerPriceData); 
    const burnAmountData = await voxelversebitcoinminer.burnAmount();
    console.log(burnAmountData);
    const discountedPriceData = await voxelversebitcoinminer.discountedPrice();
    console.log(discountedPriceData);
  
    expect(dailyBlocksData.toString()).to.equal('17000');
  });

  it('Should return the Prospect balance of the owner', async function () {
    const ownerBalance = await prospect.balanceOf(owner.address);
    console.log('Owner address:', owner.address);
    console.log('Owner Prospect balance:', ownerBalance.toString());
  
    expect(ownerBalance.toString()).to.equal('500000000000000000000000');
  }); 

  it('Should deposit Prospect to the distribution pool', async function () {
    const ownerBalancePrior = await prospect.balanceOf(owner.address);
    console.log('Owner address:', owner.address);
    console.log('Owner Prospect balance:', ownerBalancePrior.toString());
    await distributionpool.deposit(ethers.utils.parseEther('10000'), 0);
    const ownerBalancePost = await prospect.balanceOf(owner.address);
    console.log('Owner Prospect balance:', ownerBalancePost.toString());

  
    expect(ownerBalancePost.toString()).to.equal('490000000000000000000000');
  });

  it('Should mint 1 Pickaxe', async function () {
    const ownerBalanceBefore = await pickaxes.balanceOf(owner.address);
    console.log(ownerBalanceBefore);
    await pickaxes.mintPickaxe();
    const ownerBalanceAfter = await pickaxes.balanceOf(owner.address);
    console.log(ownerBalanceAfter);
    expect(ownerBalanceAfter).to.equal(ownerBalanceBefore.add(1));
  });

  it('Should mint 500 wood to the contract owner', async function () {
    const mintAmount = 500;
    const ownerBalanceBefore = await voxelversewood.balanceOf(owner.address, 1);
    console.log(ownerBalanceBefore);
    await voxelversewood.mintOwner(mintAmount);
    const ownerBalanceAfter = await voxelversewood.balanceOf(owner.address, 1);
    console.log(ownerBalanceAfter);
    expect(ownerBalanceAfter).to.equal(ownerBalanceBefore.add(500));
  });



  it('Should mint 500 stone', async function () {
    const mintAmount = 500;
    const ownerBalanceBefore = await voxelversestone.balanceOf(owner.address, 2);
    console.log(ownerBalanceBefore);
    await voxelversestone.mintOwner(mintAmount);
    const ownerBalanceAfter = await voxelversestone.balanceOf(owner.address, 2);
    console.log(ownerBalanceAfter);
    expect(ownerBalanceAfter).to.equal(ownerBalanceBefore.add(500));
  });

  it('Should mint 1 Windmill', async function () {
    const _cap = 150; // Example cap value
    const _pid = 0;   // Example pid value

    await voxelversewindmill.mintWindmill(_cap, _pid);

    console.log("Windmill minted with cap:", _cap);

  });

  it("Should return the Windmill for a user with a windmill", async function () {
    const userAddress = owner.address;

    const windmill = await voxelversewindmill.checkIfUserHasWindmill(userAddress);
    expect(windmill.tokenId).to.equal(10000);
    expect(windmill.currentPowerUsed).to.equal(0);
    expect(windmill.windmillCap).to.equal(150);
    // Add more checks as needed for other fields in the Windmill struct
    console.log(windmill);
  });

  it('Should boost windmill capacity', async function () {
    const tokenId = 10000;  // Replace with a valid windmill token ID
    const amount = 100;     // Amount to increase the windmill capacity
    const _pid = 0;         // Replace with the appropriate _pid

    const windmillDataBefore = await voxelversewindmill.windmills(tokenId);
    console.log(windmillDataBefore);

    // Ensure the caller is the owner of the windmill
    await voxelversewindmill.boostWindmillCap(tokenId, amount, _pid);

    const windmillDataAfter = await voxelversewindmill.windmills(tokenId);
    console.log(windmillDataAfter);
;
    expect(windmillDataAfter.windmillCap).to.equal(windmillDataBefore.windmillCap.add(amount));
});


  it('Should mint 1 Bitcoin Miner', async function () {
    const _pid = 0;   // Example pid value
    const _token = 10000;
    const ownerBalanceBefore = await voxelversebitcoinminer.balanceOf(owner.address);
    const windmillDataBefore = await voxelversewindmill.windmills(_token);
    console.log(ownerBalanceBefore);
    console.log(windmillDataBefore);
    await voxelversebitcoinminer.mintNoReferral(_pid, _token);
    const ownerBalanceAfter = await voxelversebitcoinminer.balanceOf(owner.address);
    const windmillDataAfter = await voxelversewindmill.windmills(_token);
    console.log(ownerBalanceAfter);
    console.log(windmillDataAfter);
    expect(ownerBalanceAfter).to.equal(ownerBalanceBefore.add(1));
  });

  it('Should initialize bitcoin mining', async function () {
    const emissionRate = ethers.utils.parseUnits("0.1", "ether"); // 0.1 ether in wei
    await voxelversebitcoinminer.setBtcEmissionRate(emissionRate);
    const btcRewardData = await voxelversebitcoinminer.btcReward();
    console.log(btcRewardData); 
  })
 
  it('Should mint 1 Skale Miner', async function () {
    const _pid = 0;   // Example pid value
    const _token = 10000;
    const ownerBalanceBefore = await voxelverseskaleminer.balanceOf(owner.address);
    const windmillDataBefore = await voxelversewindmill.windmills(_token);
    console.log(ownerBalanceBefore);
    console.log(windmillDataBefore);
    await voxelverseskaleminer.mintNoReferral(_pid, _token);
    const ownerBalanceAfter = await voxelverseskaleminer.balanceOf(owner.address);
    const windmillDataAfter = await voxelversewindmill.windmills(_token);
    console.log(ownerBalanceAfter);
    console.log(windmillDataAfter);
    expect(ownerBalanceAfter).to.equal(ownerBalanceBefore.add(1));
  });

  it('Should initialize skale mining', async function () {
    const skaleEmissionRate = ethers.utils.parseUnits("1000", "ether"); // 0.1 ether in wei
    await voxelverseskaleminer.setSklEmissionRate(skaleEmissionRate);
    const sklRewardData = await voxelverseskaleminer.sklReward();
    console.log(sklRewardData); 
  })

  it('Should transfer PROSPECT from owner to user', async function () {
    const _amount = ethers.utils.parseUnits("10000", "ether"); // 10000 tokens in wei
    const ownerBalanceBefore = await prospect.balanceOf(owner.address);
    const addr1BalanceBefore = await prospect.balanceOf(addr1.address);

    console.log("Owner balance before:", ownerBalanceBefore.toString());
    console.log("User balance before:", addr1BalanceBefore.toString());

    await prospect.connect(owner).transfer(addr1.address, _amount);

    const ownerBalanceAfter = await prospect.balanceOf(owner.address);
    const addr1BalanceAfter = await prospect.balanceOf(addr1.address);

    console.log("Owner balance after:", ownerBalanceAfter.toString());
    console.log("User balance after:", addr1BalanceAfter.toString());

    expect(addr1BalanceAfter).to.equal(addr1BalanceBefore.add(_amount));
    expect(ownerBalanceAfter).to.equal(ownerBalanceBefore.sub(_amount));
  });


  it('Should mint 1 Pickaxe for user', async function () {
    const userBalanceBefore = await pickaxes.balanceOf(addr1.address);
    console.log(userBalanceBefore);
    await pickaxes.connect(addr1).mintPickaxe();
    const userBalanceAfter = await pickaxes.balanceOf(addr1.address);
    console.log(userBalanceAfter);
    expect(userBalanceAfter).to.equal(userBalanceBefore.add(1));
  });

  it('Should mint 500 wood to user', async function () {
    const mintAmount = 500;
    const userBalanceBefore = await voxelversewood.balanceOf(addr1.address, 1);
    console.log(userBalanceBefore);
    await voxelversewood.connect(addr1).mintOwner(mintAmount);
    const userBalanceAfter = await voxelversewood.balanceOf(addr1.address, 1);
    console.log(userBalanceAfter);
    expect(userBalanceAfter).to.equal(userBalanceBefore.add(500));
  });



  it('Should mint 500 stone to user', async function () {
    const mintAmount = 500;
    const userBalanceBefore = await voxelversestone.balanceOf(addr1.address, 2);
    console.log(userBalanceBefore);
    await voxelversestone.connect(addr1).mintOwner(mintAmount);
    const userBalanceAfter = await voxelversestone.balanceOf(addr1.address, 2);
    console.log(userBalanceAfter);
    expect(userBalanceAfter).to.equal(userBalanceBefore.add(500));
  });

  it('Should mint 1 Windmill for user', async function () {
    const _cap = 150; // Example cap value
    const _pid = 0;   // Example pid value

    await voxelversewindmill.connect(addr1).mintWindmill(_cap, _pid);

    console.log("Windmill minted with cap:", _cap);

  });

  it('Should mint 1 Bitcoin Miner for new user using owner as referrer', async function () {
    const referrerAddress = owner.address;
    const _pid = 0;
    const _token = 10001;
    const userBalanceBefore = await voxelversebitcoinminer.balanceOf(addr1.address);
    const userWindmillDataBefore = await voxelversewindmill.windmills(_token);
    const ownerClaimBalanceBefore = await claimtoken.balanceOf(owner.address);
    console.log(userBalanceBefore);
    console.log(userWindmillDataBefore);
    console.log(ownerClaimBalanceBefore);
    await referrers.connect(addr1).mintBmWithReferral(_pid, referrerAddress, _token);
    const userBalanceAfter = await voxelversebitcoinminer.balanceOf(addr1.address);
    const userWindmillDataAfter = await voxelversewindmill.windmills(_token);
    const ownerClaimBalanceAfter = await claimtoken.balanceOf(owner.address);
    console.log(userBalanceAfter);
    console.log(userWindmillDataAfter);
    console.log(ownerClaimBalanceAfter);
  })

  it('Should return miner data for owner bitcoin miner', async function () {
    // Advance 10 blocks
    await advanceBlocks(16500);
    const _token = 1;
    const minerData = await voxelversebitcoinminer.miners(_token);
    console.log(minerData);
  })

  it('Should get pending rewards for owner bitcoin miner', async function () {
    const _token = 1;
    const pendingRewards = await voxelversebitcoinminer.getPendingRewards(_token);
    console.log(pendingRewards);
  })

  it('Should claim rewards for owner bitcoin miner', async function () {
    const _token = 1;
    const prospectBalanceBefore = await prospect.balanceOf(owner.address);
    console.log(prospectBalanceBefore);
    await voxelversebitcoinminer.claimRewards(_token);
    const prospectBalanceAfter = await prospect.balanceOf(owner.address);
    console.log(prospectBalanceAfter);
  })

  it('Should boost Bitcoin Miner hashrate 1 times for owner', async function () {
    const _token = 1;
    const _windToken = 10000;
    const _pid = 0;
    const minerDataBefore = await voxelversebitcoinminer.miners(_token);
    const windmillDataBefore = await voxelversewindmill.windmills(_windToken);
    console.log(minerDataBefore);
    console.log(windmillDataBefore);
    await voxelversebitcoinminer.boostMinerHash(_token, _pid, _windToken);
    const minerDataAfter = await voxelversebitcoinminer.miners(_token);
    const windmillDataAfter = await voxelversewindmill.windmills(_windToken);
    console.log(minerDataAfter);
    console.log(windmillDataAfter);
  });

  it('Should boost Bitcoin Miner hashrate 5 times for owner', async function () {
    const _token = 1;
    const _windToken = 10000;
    const _pid = 0;
    const numBoosts = 5;

    const minerDataBefore = await voxelversebitcoinminer.miners(_token);
    const windmillDataBefore = await voxelversewindmill.windmills(_windToken);
    console.log(minerDataBefore);
    console.log(windmillDataBefore);

    for (let i = 0; i < numBoosts; i++) {
        await voxelversebitcoinminer.boostMinerHash(_token, _pid, _windToken);
    }

    const minerDataAfter = await voxelversebitcoinminer.miners(_token);
    const windmillDataAfter = await voxelversewindmill.windmills(_windToken);
    console.log(minerDataAfter);
    console.log(windmillDataAfter);
  });

  it('Should return total referrals for owner address', async function () {
    const amountOfReferrals = await referrers.totalReferrals(owner.address);
    console.log(amountOfReferrals);
  })


});