import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const LiskGardenModule = buildModule("LiskGardenModule", (m) => {
  const gardenTokenAddress = m.getParameter("gardenTokenAddress");
  const plantNFTAddress = m.getParameter("plantNFTAddress");
  const gameItemsAddress = m.getParameter("gameItemsAddress");

  const liskGarden = m.contract("LiskGarden", [
    gardenTokenAddress,
    plantNFTAddress,
    gameItemsAddress,
  ]);

  return { liskGarden };
});

export default LiskGardenModule;