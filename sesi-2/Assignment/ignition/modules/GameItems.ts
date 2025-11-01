import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const GameItemsModule = buildModule("GameItemsModule", (m) => {
  const plantNFTAddress = m.getParameter("plantNFTAddress");

  const gameItems = m.contract("GameItems", [plantNFTAddress]);

  return { gameItems };
});

export default GameItemsModule;