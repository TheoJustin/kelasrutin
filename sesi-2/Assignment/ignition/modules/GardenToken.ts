import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const GardenTokenModule = buildModule("GardenTokenModule", (m) => {
  const gameContract = m.getParameter("gameContract", "0x0000000000000000000000000000000000000000");
  const initialSupply = m.getParameter("initialSupply", 1000000n);

  const gardenToken = m.contract("GardenToken", [gameContract, initialSupply]);

  return { gardenToken };
});

export default GardenTokenModule;