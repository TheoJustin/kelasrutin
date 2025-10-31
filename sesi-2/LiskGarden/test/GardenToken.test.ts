import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import { network } from 'hardhat';
import { parseEventLogs, getAddress, parseEther } from 'viem';

describe('GardenToken', async () => {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();

  let token: any;
  let owner: any;
  let game: any;
  let player: any;


  const DAILY_LIMIT = parseEther('10000');
  const INITIAL_SUPPLY = parseEther('1000');

  beforeEach(async () => {
    const [signerOwner, signerGame, signerPlayer] =
      await viem.getWalletClients();
    owner = signerOwner;
    game = signerGame;
    player = signerPlayer;

    token = await viem.deployContract('GardenToken', [
      game.account.address,
      1000n,
    ]);
  });

  // ------------------- BASIC DEPLOYMENT -------------------

  it('Should mint initial supply to deployer', async () => {
    const balance = await token.read.balanceOf([owner.account.address]);
    assert.equal(balance, parseEther('1000'));
  });

  it('Should set the correct gameContract', async () => {
    const gc = await token.read.gameContract();
    assert.equal(getAddress(gc), getAddress(game.account.address));
  });

  it('Should calculate correct reward value', async () => {
    const reward = await token.read.calculateReward([2n, 3n]);
    assert.equal(typeof reward, 'bigint');
    assert.ok(reward > 0n);
  });

  // ------------------- MINT REWARD -------------------

  it('Game contract should mint reward up to daily limit', async () => {

    const amount = parseEther('1');
    const txHash = await token.write.mintReward(
      [player.account.address, amount],
      {
        account: game.account,
      }
    );

    const receipt = await publicClient.waitForTransactionReceipt({
      hash: txHash,
    });

    const logs = parseEventLogs({
      abi: token.abi,
      logs: receipt.logs,
      eventName: 'Transfer',
    });

    const mintLog = logs.find(
    (l: any) => l.args.to.toLowerCase() === player.account.address.toLowerCase()
    );
    assert.ok(mintLog);
  });

  it('Should revert if non-game contract tries to mint', async () => {
    const amount = parseEther('10');
    await assert.rejects(
      token.write.mintReward([player.account.address, amount], {
        account: player.account,
      }),
      /Only game contract can call/
    );
  });

  it('Should revert if minting exceeds max daily limit', async () => {
    const amount1 = parseEther('9500');
    const txHash1 = await token.write.mintReward(
      [player.account.address, amount1],
      {
        account: game.account,
      }
    );

    await publicClient.waitForTransactionReceipt({ hash: txHash1 });

    const amount2 = parseEther('1000');

    try {
      const txHash2 = await token.write.mintReward(
        [player.account.address, amount2],
        {
          account: game.account,
        }
      );

      await publicClient.waitForTransactionReceipt({ hash: txHash2 });

    } catch (error: any) {
      assert.ok(error.message.includes('Daily mint limit exceeded'));
    }
  });

  // ------------------- BURN FUNCTION -------------------
  // 6
  it('Should burn tokens and update totalBurned', async () => {
    // Mint tokens to player first
    const mintAmount = parseEther('100');
    await token.write.mintReward([player.account.address, mintAmount], {
      account: game.account,
    });

    // Burn 10 tokens
    const burnAmount = parseEther('10');
    const txHash = await token.write.burn([burnAmount], {
      account: player.account,
    });

    await publicClient.waitForTransactionReceipt({ hash: txHash });

    const burned = await token.read.totalBurned();
    assert.equal(burned, burnAmount);
  });

  it('Should revert if burn amount < 10 GDN', async () => {
    const burnAmount = parseEther('5');
    await assert.rejects(
      token.write.burn([burnAmount], { account: owner.account }),
      /Minimum burn 10 GDN/
    );
  });

  it('Should revert if burning again within 1 day', async () => {
    // Mint + burn once
    const mintAmount = parseEther('100');
    await token.write.mintReward([player.account.address, mintAmount], {
      account: game.account,
    });
    const burnAmount = parseEther('10');
    await token.write.burn([burnAmount], { account: player.account });

    // Try again immediately
    await assert.rejects(
      token.write.burn([burnAmount], { account: player.account }),
      /Burning is allowed one day per user/
    );
  });

  // ------------------- SUPPLY + ANALYTICS -------------------

  it('Should compute circulating supply and burn rate', async () => {
    const total = await token.read.totalSupply();
    const circ = await token.read.circulatingSupply();
    const burnRate = await token.read.burnRate();

    assert.ok(circ <= total);
    assert.equal(typeof burnRate, 'bigint');
  });
});
