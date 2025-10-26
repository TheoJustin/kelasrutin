import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const BasicTokenModule = buildModule('BasicTokenModule', (m) => {
  // Initial supply: 1 juta token
  // Catatan: 1 token = 1 (tanpa decimals dulu)
  const initialSupply = 1_000_000;

  const basicToken = m.contract('BasicToken', [initialSupply]);

  return { basicToken };
});

export default BasicTokenModule;
