import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DeployAllModule = buildModule("DeployAllModule", (m) => {
  const deployer = m.getAccount(0);
  const initialSupply = m.getParameter("initialSupply", 1000000n);

  // Deploy GardenToken first (with placeholder game contract)
  const gardenToken = m.contract("GardenToken", [deployer, initialSupply]);

  // Deploy PlantNFT with GardenToken address
  const plantNFT = m.contract("PlantNFT", [gardenToken]);

  // Deploy GameItems with PlantNFT address
  const gameItems = m.contract("GameItems", [plantNFT]);

  // Deploy LiskGarden with all contract addresses
  const liskGarden = m.contract("LiskGarden", [gardenToken, plantNFT, gameItems]);

  // Set up contract connections
  m.call(plantNFT, "setGameItemsContract", [gameItems]);

  return { gardenToken, plantNFT, gameItems, liskGarden };
});

export default DeployAllModule;