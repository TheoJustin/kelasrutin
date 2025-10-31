// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./GardenToken.sol";
import "./PlantNFT.sol";
import "./GameItems.sol";

/**
 * @title LiskGarden
 * @dev Main game contract yang orchestrate semua token contracts
 */
contract LiskGarden {

    GardenToken public immutable gardenToken;
    PlantNFT public immutable plantNFT;
    GameItems public immutable gameItems;

    address public owner;

    constructor(
        address _gardenToken,
        address _plantNFT,
        address _gameItems
    ) {
        gardenToken = GardenToken(_gardenToken);
        plantNFT = PlantNFT(_plantNFT);
        gameItems = GameItems(_gameItems);
        owner = msg.sender;
    }

    // TODO: Implement game logic

    uint256 public constant PLANT_PRICE_WEI = 0.0000001 ether;

    event PlantSeeded(address indexed owner, uint256 indexed plantId);
    event PlantHarvested(uint256 indexed plantId, address indexed owner, uint256 reward);
    event Funded(address indexed sender, uint256 amount);

    function plantSeed(string memory name, string memory species) external payable returns (uint256) {
        require(msg.value >= PLANT_PRICE_WEI, "Insufficient payment for planting fee");
        
        uint256 newId = plantNFT.mintPlant{value: msg.value}(name, species);

        emit PlantSeeded(msg.sender, newId);

        return newId;
    }

    function waterPlant(uint256 plantId) external {
        plantNFT.waterPlant(plantId);
    }

    function harvestPlant(uint256 plantId) external returns (uint256 rewardAmount) {
        require(plantNFT.ownerOf(plantId) == msg.sender, "Not the owner");
        
        rewardAmount = plantNFT.harvestPlant(plantId);

        emit PlantHarvested(plantId, msg.sender, rewardAmount);
    }

    function useItemOnPlant(uint256 plantId, uint256 itemId) external {
        gameItems.useItem(plantId, itemId);
    }

    function fund() external payable {
        require(msg.value > 0, "Must send funds");
        emit Funded(msg.sender, msg.value);
    }

    function withdraw() external {
        require(msg.sender == owner, "Only the owner can withdraw");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}