import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const PlantNFTModule = buildModule("PlantNFTModule", (m) => {
  const gardenTokenAddress = m.getParameter("gardenTokenAddress");

  const plantNFT = m.contract("PlantNFT", [gardenTokenAddress]);

  return { plantNFT };
});

export default PlantNFTModule;