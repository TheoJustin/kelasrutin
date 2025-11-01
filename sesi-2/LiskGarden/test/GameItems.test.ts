import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import { network } from 'hardhat';
import { getAddress, parseEventLogs } from 'viem';

describe('GameItems Contract', async () => {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();

  let gameItems: any;
  let plantNFT: any;
  let gardenToken: any;
  let alice: any;
  let bob: any;

  const FERTILIZER = 1n;
  const GROWTH_BOOST_1H = 2n;

  beforeEach(async () => {
    // Get wallet signers from hardhat
    const [signerAlice, signerBob] = await viem.getWalletClients();
    alice = signerAlice;
    bob = signerBob;

    // Deploy GardenToken with placeholder and initial supply
    gardenToken = await viem.deployContract('GardenToken', [
      alice.account.address,
      BigInt('1000000'), // 1 million tokens with 18 decimals
    ]);

    // Deploy PlantNFT contract with GardenToken address
    plantNFT = await viem.deployContract('PlantNFT', [gardenToken.address]);

    // Deploy GameItems contract with PlantNFT address
    gameItems = await viem.deployContract('GameItems', [plantNFT.address]);

    // Set GameItems contract in PlantNFT
    await plantNFT.write.setGameItemsContract([gameItems.address], {
      account: alice.account,
    });
  });

  async function mintPlantFor(player: any) {
    const txHash = await plantNFT.write.mintPlant(
      ['Test Plant', 'Test Species'],
      {
        account: player.account,
        value: BigInt('1000000000000000'), // 0.001 ether
      }
    );
    const receipt = await publicClient.waitForTransactionReceipt({
      hash: txHash,
    });
    const logs = parseEventLogs({
      abi: plantNFT.abi,
      logs: receipt.logs,
      eventName: 'PlantMinted',
    });
    return (logs[0] as any).args.tokenId as bigint;
  }

  async function mintItemFor(player: any, itemId: bigint, amount: bigint) {
    await gameItems.write.mint([player.account.address, itemId, amount, '0x'], {
      account: alice.account,
    });
  }

  it('Should initialize with correct item effects', async () => {
    const fertilizerEffect = await gameItems.read.itemEffects([FERTILIZER]);

    assert.equal(
      Number(fertilizerEffect[0]), // growthMultiplier
      200,
      'Fertilizer should have 2x multiplier'
    );
    assert.equal(Number(fertilizerEffect[1]), 0); // rarityBoost
    assert.equal(
      Number(fertilizerEffect[2]), // durationSeconds
      0,
      'Fertilizer should be instant'
    );
    assert.equal(
      fertilizerEffect[3], // isConsumable
      true,
      'Fertilizer should be consumable'
    );
  });

  it('Should initialize Growth Boost 1H with correct effects', async () => {
    const boostEffect = await gameItems.read.itemEffects([GROWTH_BOOST_1H]);

    assert.equal(
      Number(boostEffect[0]), // growthMultiplier
      300,
      'Growth Boost should have 3x multiplier'
    );
    assert.equal(
      Number(boostEffect[2]), // durationSeconds
      3600,
      'Should last 1 hour'
    );
    assert.equal(boostEffect[3], true, 'Should be consumable'); // isConsumable
  });

  it('Alice should be able to use fertilizer on her plant', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, FERTILIZER, 1n);

    const txHash = await gameItems.write.useItem([plantId, FERTILIZER], {
      account: alice.account,
    });

    const receipt = await publicClient.waitForTransactionReceipt({
      hash: txHash,
    });

    const logs = parseEventLogs({
      abi: gameItems.abi,
      logs: receipt.logs,
      eventName: 'ItemUsed',
    });

    assert.equal(
      getAddress((logs[0] as any).args.player),
      getAddress(alice.account.address)
    );
    assert.equal((logs[0] as any).args.itemId, FERTILIZER);
  });

  it("Should revert if player doesn't own the item", async () => {
    const plantId = await mintPlantFor(alice);

    await assert.rejects(
      gameItems.write.useItem([plantId, FERTILIZER], {
        account: alice.account,
      }),
      /Insufficient item balance/
    );
  });

  it("Should revert if player doesn't own the plant", async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(bob, FERTILIZER, 1n);

    await assert.rejects(
      gameItems.write.useItem([plantId, FERTILIZER], {
        account: bob.account,
      }),
      /Not the plant owner/
    );
  });

  it('Should burn consumable item after use', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, FERTILIZER, 1n);

    const balanceBefore = await gameItems.read.balanceOf([
      alice.account.address,
      FERTILIZER,
    ]);

    await gameItems.write.useItem([plantId, FERTILIZER], {
      account: alice.account,
    });

    const balanceAfter = await gameItems.read.balanceOf([
      alice.account.address,
      FERTILIZER,
    ]);

    assert.equal(Number(balanceBefore), 1);
    assert.equal(Number(balanceAfter), 0, 'Item should be burned');
  });

  it('Should create active boost for timed items', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, GROWTH_BOOST_1H, 1n);

    await gameItems.write.useItem([plantId, GROWTH_BOOST_1H], {
      account: alice.account,
    });

    const boosts = await gameItems.read.getActiveBoosts([
      alice.account.address,
      plantId,
    ]);

    assert.equal(boosts.length, 1, 'Should have one active boost');
    assert.equal(Number(boosts[0].multiplier), 300); // multiplier
  });

  it('Should calculate correct effective growth rate with one boost', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, GROWTH_BOOST_1H, 1n);

    await gameItems.write.useItem([plantId, GROWTH_BOOST_1H], {
      account: alice.account,
    });

    const effectiveRate = await gameItems.read.getEffectiveGrowthRate([
      alice.account.address,
      plantId,
    ]);

    assert.equal(Number(effectiveRate), 300, 'Should have 3x growth rate');
  });

  it('Should calculate correct effective growth rate with multiple boosts', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, GROWTH_BOOST_1H, 2n);

    await gameItems.write.useItem([plantId, GROWTH_BOOST_1H], {
      account: alice.account,
    });
    await gameItems.write.useItem([plantId, GROWTH_BOOST_1H], {
      account: alice.account,
    });

    const effectiveRate = await gameItems.read.getEffectiveGrowthRate([
      alice.account.address,
      plantId,
    ]);

    assert.equal(
      Number(effectiveRate),
      500,
      'Should have 5x growth rate (3x + 3x - 100)'
    );
  });

  it('Should track item usage statistics', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, FERTILIZER, 3n);

    await gameItems.write.useItem([plantId, FERTILIZER], {
      account: alice.account,
    });

    await gameItems.write.useItem([plantId, FERTILIZER], {
      account: alice.account,
    });

    const usageCount = await gameItems.read.itemUsageCount([FERTILIZER]);
    const playerUsage = await gameItems.read.playerItemUsage([
      alice.account.address,
      FERTILIZER,
    ]);

    assert.equal(Number(usageCount), 2);
    assert.equal(Number(playerUsage), 2);
  });

  it('Should handle batch item usage', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, FERTILIZER, 3n);
    await mintItemFor(alice, GROWTH_BOOST_1H, 2n);

    await gameItems.write.useItemBatch(
      [plantId, [FERTILIZER, GROWTH_BOOST_1H], [1n, 1n]],
      { account: alice.account }
    );

    const fertilizerUsage = await gameItems.read.itemUsageCount([FERTILIZER]);
    const boostUsage = await gameItems.read.itemUsageCount([GROWTH_BOOST_1H]);

    assert.equal(Number(fertilizerUsage), 1);
    assert.equal(Number(boostUsage), 1);
  });

  it('Should revert batch usage with mismatched arrays', async () => {
    const plantId = await mintPlantFor(alice);

    await assert.rejects(
      gameItems.write.useItemBatch(
        [plantId, [FERTILIZER, GROWTH_BOOST_1H], [2n]],
        { account: alice.account }
      ),
      /Mismatched arrays/
    );
  });

  it('Should return most used items correctly', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, FERTILIZER, 5n);
    await mintItemFor(alice, GROWTH_BOOST_1H, 2n);

    // Use fertilizer 5 times
    for (let i = 0; i < 5; i++) {
      await gameItems.write.useItem([plantId, FERTILIZER], {
        account: alice.account,
      });
    }

    // Use growth boost 2 times
    for (let i = 0; i < 2; i++) {
      await gameItems.write.useItem([plantId, GROWTH_BOOST_1H], {
        account: alice.account,
      });
    }

    const result = await gameItems.read.getMostUsedItems([2n]);
    const [itemIds, usageCounts] = result;

    assert.equal(
      Number(itemIds[0]),
      Number(FERTILIZER),
      'Fertilizer should be most used'
    );
    assert.equal(Number(usageCounts[0]), 5);
    assert.equal(Number(itemIds[1]), Number(GROWTH_BOOST_1H));
    assert.equal(Number(usageCounts[1]), 2);
  });

  it('Should remove expired boosts when calculating growth rate', async () => {
    const plantId = await mintPlantFor(alice);
    await mintItemFor(alice, GROWTH_BOOST_1H, 1n);

    await gameItems.write.useItem([plantId, GROWTH_BOOST_1H], {
      account: alice.account,
    });

    // Verify boost is active
    let effectiveRate = await gameItems.read.getEffectiveGrowthRate([
      alice.account.address,
      plantId,
    ]);
    assert.equal(
      Number(effectiveRate),
      300,
      'Should have 3x growth rate initially'
    );

    // Fast forward time by more than 1 hour (3600 seconds)
    await publicClient.request({
      method: 'evm_increaseTime' as any,
      params: [3660] as any, // 1 hour + 1 minute
    });
    await publicClient.request({
      method: 'evm_mine' as any,
      params: [] as any,
    });

    effectiveRate = await gameItems.read.getEffectiveGrowthRate([
      alice.account.address,
      plantId,
    ]);

    assert.equal(
      Number(effectiveRate),
      100,
      'Should return to base rate after expiry'
    );
  });

  it('Alice and Bob should have independent item usage statistics', async () => {
    const alicePlantId = await mintPlantFor(alice);
    const bobPlantId = await mintPlantFor(bob);

    await mintItemFor(alice, FERTILIZER, 3n);
    await mintItemFor(bob, FERTILIZER, 2n);

    await gameItems.write.useItem([alicePlantId, FERTILIZER], {
      account: alice.account,
    });

    await gameItems.write.useItem([alicePlantId, FERTILIZER], {
      account: alice.account,
    });

    await gameItems.write.useItem([bobPlantId, FERTILIZER], {
      account: bob.account,
    });

    const aliceUsage = await gameItems.read.playerItemUsage([
      alice.account.address,
      FERTILIZER,
    ]);
    const bobUsage = await gameItems.read.playerItemUsage([
      bob.account.address,
      FERTILIZER,
    ]);

    assert.equal(Number(aliceUsage), 2);
    assert.equal(Number(bobUsage), 1);
  });
});
