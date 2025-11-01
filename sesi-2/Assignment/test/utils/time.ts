import hre from 'hardhat';

export async function advanceTimeAndMine(seconds: number) {
  await (hre.network as any).provider.send('evm_increaseTime', [seconds]);
  await (hre.network as any).provider.send('evm_mine');
}
