import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import { network } from 'hardhat';
import { parseEventLogs, getAddress, parseEther } from 'viem';

describe('PlantNFT Contract', async () => {
  const { networkHelpers } = await network.connect();

  let gardenToken: any;
  let plantNFT: any;
  let owner: any;
  let player: any;
  let gardenAddress: string;

  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();

  beforeEach(async () => {
    const [signerOwner, signerPlayer] = await viem.getWalletClients();
    owner = signerOwner;
    player = signerPlayer;

    // Deploy GardenToken first
    gardenToken = await viem.deployContract('GardenToken', [
      owner.account.address,
      1000n,
    ]);
    gardenAddress = gardenToken.address;

    // Deploy PlantNFT
    plantNFT = await viem.deployContract('PlantNFT', [
      getAddress(gardenAddress),
    ]);
  });

  // Helper function to reliably get the tokenId from a Mint event
  async function getMintedTokenId(txHash: `0x${string}`) {
    const receipt = await publicClient.waitForTransactionReceipt({
      hash: txHash,
    });
    const logs = parseEventLogs({
      abi: plantNFT.abi,
      logs: receipt.logs,
      eventName: 'PlantMinted',
    });
    assert.ok(logs.length > 0, 'PlantMinted event not found');
    return { tokenId: (logs[0] as any).args.tokenId, receipt: receipt };
  }

  // ----------------------------------------------------------------
  // 1️⃣ Mint plant successfully
  // ----------------------------------------------------------------
  it('Should mint a new plant NFT and emit PlantMinted', async () => {
    const txHash = await plantNFT.write.mintPlant(['Rose', 'Rosa'], {
      account: player.account,
      value: parseEther('0.001'),
    });

    const { tokenId } = await getMintedTokenId(txHash);
    const plant = await plantNFT.read.plants([tokenId]);

    assert.equal(plant.name, 'Rose');
    assert.equal(plant.species, 'Rosa');
    assert.equal(Number(plant.stage), 1);
  });

  // ----------------------------------------------------------------
  // 2️⃣ Revert if mint payment too low
  // ----------------------------------------------------------------
  it('Should revert if mint payment is less than 0.001 ETH', async () => {
    await assert.rejects(
      plantNFT.write.mintPlant(['Daisy', 'Bellis'], {
        account: player.account,
        value: parseEther('0.0005'),
      }),
      /Insufficient payment/
    );
  });

  // ----------------------------------------------------------------
  // 3️⃣ Each minted plant has increasing tokenId
  // ----------------------------------------------------------------
  it('Should increment nextTokenId for each mint', async () => {
    await plantNFT.write.mintPlant(['A', 'AA'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    await plantNFT.write.mintPlant(['B', 'BB'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const nextTokenId = await plantNFT.read.nextTokenId();
    assert.equal(Number(nextTokenId), 2);
  });

  // ----------------------------------------------------------------
  // 4️⃣ Owner of minted NFT must be the minter
  // ----------------------------------------------------------------
  it('Minted plant should belong to the caller', async () => {
    const txHash = await plantNFT.write.mintPlant(['Sunflower', 'Helianthus'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    const nftOwner = await plantNFT.read.ownerOf([tokenId]);
    assert.equal(nftOwner.toLowerCase(), player.account.address.toLowerCase());
  });

  // ----------------------------------------------------------------
  // 5️⃣ Watering increases water count
  // ----------------------------------------------------------------
  it('Should increase water count when watering', async () => {
    const txHash = await plantNFT.write.mintPlant(['Tulip', 'Tulipa'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    // Skip cooldown by simulating time (8 hours + 1 second)
    await networkHelpers.time.increase(8 * 3600 + 1);
    await plantNFT.write.waterPlant([tokenId], { account: player.account });

    // Check the waterCount mapping
    const count = await plantNFT.read.waterCount([tokenId]);
    assert.equal(Number(count), 1);
  });

  // ----------------------------------------------------------------
  // 6️⃣ Watering before cooldown should revert
  // ----------------------------------------------------------------
  it('Should revert watering before 8 hours', async () => {
    const txHash = await plantNFT.write.mintPlant(['Tulip', 'Tulipa'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    // Try watering immediately (less than 8 hours)
    await assert.rejects(
      plantNFT.write.waterPlant([tokenId], { account: player.account }),
      /Watering cooldown active/
    );
  });

  // ----------------------------------------------------------------
  // 7️⃣ Only owner can water
  // ----------------------------------------------------------------
  it('Should revert if non-owner tries to water', async () => {
    const txHash = await plantNFT.write.mintPlant(['Orchid', 'Phalaenopsis'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    const [_, __, bob] = await viem.getWalletClients();

    await networkHelpers.time.increase(8 * 3600 + 1);
    await assert.rejects(
      plantNFT.write.waterPlant([tokenId], { account: bob.account }),
      /Not the owner of the plant/
    );
  });

  // ----------------------------------------------------------------
  // 8️⃣ canGrow() should be false initially
  // ----------------------------------------------------------------
  it('Should return false for canGrow initially', async () => {
    const txHash = await plantNFT.write.mintPlant(['Cactus', 'Opuntia'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    const canGrow = await plantNFT.read.canGrow([tokenId]);
    assert.equal(canGrow, false);
  });

  // ----------------------------------------------------------------
  // 9️⃣ Grow should revert if requirements not met
  // ----------------------------------------------------------------
  it('Should revert growPlant if requirements not met', async () => {
    const txHash = await plantNFT.write.mintPlant(['Lily', 'Lilium'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    await assert.rejects(
      plantNFT.write.growPlant([tokenId], { account: player.account }),
      /Growth requirements not met/
    );
  });

  // ----------------------------------------------------------------
  // 🔟 Water enough and wait 1 day -> canGrow true
  // ----------------------------------------------------------------
  it('Should allow growth after 3 waterings and 1 day', async () => {
    const txHash = await plantNFT.write.mintPlant(['Fern', 'Pteridophyta'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    // Perform 3 waterings, respecting cooldown
    for (let i = 0; i < 3; i++) {
      await networkHelpers.time.increase(8 * 3600 + 1);
      await plantNFT.write.waterPlant([tokenId], { account: player.account });
    }

    const canGrow = await plantNFT.read.canGrow([tokenId]);
    assert.equal(canGrow, true);
  });

  // ----------------------------------------------------------------
  // 11️⃣ GrowPlant increases stage
  // ----------------------------------------------------------------
  it('Should increase stage when growPlant called', async () => {
    const txHash = await plantNFT.write.mintPlant(['Bamboo', 'Poaceae'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    // Meet growth requirements
    for (let i = 0; i < 3; i++) {
      await networkHelpers.time.increase(8 * 3600 + 1);
      await plantNFT.write.waterPlant([tokenId], { account: player.account });
    }

    // Grow the plant from stage 1 -> 2
    await plantNFT.write.growPlant([tokenId], { account: player.account });

    const plant = await plantNFT.read.plants([tokenId]);
    assert.equal(Number(plant.stage), 2);
  });

  // ----------------------------------------------------------------
  // 12️⃣ Should not grow beyond stage 3
  // ----------------------------------------------------------------
  it('Should not grow beyond stage 3', async () => {
    const txHash = await plantNFT.write.mintPlant(['Pine', 'Pinus'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    // Stage 1 -> 2
    for (let i = 0; i < 3; i++) {
      await networkHelpers.time.increase(8 * 3600 + 1);
      await plantNFT.write.waterPlant([tokenId], { account: player.account });
    }
    await plantNFT.write.growPlant([tokenId], { account: player.account }); // Stage 2

    // Stage 2 -> 3 (Maturity)
    for (let i = 0; i < 3; i++) {
      await networkHelpers.time.increase(8 * 3600 + 1);
      await plantNFT.write.waterPlant([tokenId], { account: player.account });
    }
    await networkHelpers.time.increase(24 * 3600 + 1); // Wait for time since last growth
    await plantNFT.write.growPlant([tokenId], { account: player.account }); // Stage 3

    let plant = await plantNFT.read.plants([tokenId]);
    assert.equal(Number(plant.stage), 3);

    // Check that canGrow is now false
    const canGrow = await plantNFT.read.canGrow([tokenId]);
    assert.equal(canGrow, false);

    // Try to grow again and expect a revert
    await assert.rejects(
      plantNFT.write.growPlant([tokenId], { account: player.account }),
      /Growth requirements not met/,
      'Grow should revert when plant is already stage 3'
    );
  });

  // ----------------------------------------------------------------
  // 13️⃣ Harvest should revert if plant not mature
  // ----------------------------------------------------------------
  it('Should revert harvest if stage < 3', async () => {
    const txHash = await plantNFT.write.mintPlant(['Palm', 'Arecaceae'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    await assert.rejects(
      plantNFT.write.harvestPlant([tokenId], { account: player.account }),
      /Plant is not mature/
    );
  });

  // ----------------------------------------------------------------
  // 14️⃣ Harvest should revert if not owner
  // ----------------------------------------------------------------
  it('Should revert harvest if not owner', async () => {
    const txHash = await plantNFT.write.mintPlant(['Mint', 'Mentha'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);
    const [_, __, bob] = await viem.getWalletClients();

    await assert.rejects(
      plantNFT.write.harvestPlant([tokenId], { account: bob.account }),
      /Not the owner of the plant/
    );
  });

  // ----------------------------------------------------------------
  // 15️⃣ Check events emission on grow
  // ----------------------------------------------------------------
  it('Should emit PlantGrown event when growing', async () => {
    const txHash = await plantNFT.write.mintPlant(['Oak', 'Quercus'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    // Meet growth requirements for stage 2
    for (let i = 0; i < 3; i++) {
      await networkHelpers.time.increase(8 * 3600 + 1);
      await plantNFT.write.waterPlant([tokenId], { account: player.account });
    }

    const growTx = await plantNFT.write.growPlant([tokenId], {
      account: player.account,
    });
    const growReceipt = await publicClient.waitForTransactionReceipt({
      hash: growTx,
    });

    const logs = parseEventLogs({
      abi: plantNFT.abi,
      logs: growReceipt.logs,
      eventName: 'PlantGrown',
    });
    assert.equal(logs.length, 1, 'PlantGrown event was not emitted');

    const decodedLog = logs[0] as any;
    assert.equal(
      decodedLog.args.tokenId,
      tokenId,
      'Token ID in event is incorrect'
    );
    assert.equal(
      Number(decodedLog.args.stage),
      2,
      'Stage in event is incorrect'
    );
  });

  // ----------------------------------------------------------------
  // 16️⃣ Harvest should distribute GardenToken rewards
  // ----------------------------------------------------------------
  it('Should mint GardenTokens upon successful harvest', async () => {
    const txHash = await plantNFT.write.mintPlant(['RewardTree', 'GT'], {
      account: player.account,
      value: parseEther('0.001'),
    });
    const { tokenId } = await getMintedTokenId(txHash);

    // Stage 1 -> 2
    for (let i = 0; i < 3; i++) {
      await networkHelpers.time.increase(8 * 3600 + 1);
      await plantNFT.write.waterPlant([tokenId], { account: player.account });
    }
    await plantNFT.write.growPlant([tokenId], { account: player.account }); // Stage 2

    // Stage 2 -> 3 (Maturity)
    for (let i = 0; i < 3; i++) {
      await networkHelpers.time.increase(8 * 3600 + 1);
      await plantNFT.write.waterPlant([tokenId], { account: player.account });
    }
    await networkHelpers.time.increase(24 * 3600 + 1); // Wait for time since last growth
    await plantNFT.write.growPlant([tokenId], { account: player.account }); // Stage 3

    // Player should have 0 GardenTokens initially
    const initialBalance = await gardenToken.read.balanceOf([
      player.account.address,
    ]);
    assert.equal(Number(initialBalance), 0, 'Initial GT balance should be 0');

    // Harvest
    await plantNFT.write.harvestPlant([tokenId], { account: player.account });

    const finalBalance = await gardenToken.read.balanceOf([
      player.account.address,
    ]);

    // Check that the balance increased
    assert.ok(
      Number(finalBalance) > 0,
      'Final GT balance should be greater than 0'
    );
  });
});
