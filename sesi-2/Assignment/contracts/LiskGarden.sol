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
    uint256 public mintCost = 0.001 ether;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

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

    /**
 * 1. Plant a seed (requires SEED item + ETH)
 */
function plantSeed(string memory name, string memory species)
    external
    payable
    returns (uint256)
{
    require(msg.value >= mintCost, "Insufficient payment");
    uint256 plantId = plantNFT.mintPlant{value: msg.value}(name, species);
    totalPlantsOwned[msg.sender]++;
    checkAndUnlockAchievements(msg.sender);
    return plantId;
}

/**
 * 2. Water plant (requires WATER_CAN item or cooldown)
 */
function waterPlant(uint256 plantId) external {
    require(plantNFT.ownerOf(plantId) == msg.sender, "Not owner");
    plantNFT.waterPlant(plantId);
}

/**
 * 3. Use fertilizer (requires FERTILIZER item)
 */
function useFertilizer(uint256 plantId) external {
    require(plantNFT.ownerOf(plantId) == msg.sender, "Not owner");
    gameItems.useItem(plantId, 1); // FERTILIZER = 1
}

/**
 * 4. Harvest mature plant
 */
function harvestPlant(uint256 plantId) external {
    require(plantNFT.ownerOf(plantId) == msg.sender, "Not owner");
    uint256 reward = plantNFT.harvestPlant(plantId);
    totalHarvested[msg.sender] += reward;
    checkAndUnlockAchievements(msg.sender);
}

/**
 * 5. Batch operations
 */
function harvestAll() external {
    // Simple implementation - would need to track owned plants in production
    uint256 totalTokens = plantNFT.nextTokenId();
    for (uint256 i = 0; i < totalTokens; i++) {
        if (plantNFT.ownerOf(i) == msg.sender) {
            PlantNFT.Plant memory plant = plantNFT.getPlant(i);
            if (plant.stage == 3) {
                uint256 reward = plantNFT.harvestPlant(i);
                totalHarvested[msg.sender] += reward;
            }
        }
    }
    checkAndUnlockAchievements(msg.sender);
}

/**
 * Leaderboard tracking
 */
mapping(address => uint256) public totalHarvested;
mapping(address => uint256) public totalPlantsOwned;

function getTopFarmers(uint256 count)
    external
    pure
    returns (address[] memory farmers, uint256[] memory harvests)
{
    // Simple implementation - in production would use more efficient sorting
    farmers = new address[](count);
    harvests = new uint256[](count);
    // Note: This is a placeholder - would need to track all farmers
    return (farmers, harvests);
}

/**
 * Achievements system
 */
enum Achievement {
    FIRST_PLANT,
    TENTH_PLANT,
    HUNDREDTH_PLANT,
    FIRST_LEGENDARY,
    MASTER_FARMER
}

mapping(address => mapping(Achievement => bool)) public achievements;
mapping(address => mapping(Achievement => uint256)) public achievementTimestamp;

event AchievementUnlocked(
    address indexed player,
    Achievement indexed achievement,
    uint256 timestamp
);

function checkAndUnlockAchievements(address player) internal {
    if (totalPlantsOwned[player] == 1 && !achievements[player][Achievement.FIRST_PLANT]) {
        achievements[player][Achievement.FIRST_PLANT] = true;
        achievementTimestamp[player][Achievement.FIRST_PLANT] = block.timestamp;
        emit AchievementUnlocked(player, Achievement.FIRST_PLANT, block.timestamp);
    }
    if (totalPlantsOwned[player] == 10 && !achievements[player][Achievement.TENTH_PLANT]) {
        achievements[player][Achievement.TENTH_PLANT] = true;
        achievementTimestamp[player][Achievement.TENTH_PLANT] = block.timestamp;
        emit AchievementUnlocked(player, Achievement.TENTH_PLANT, block.timestamp);
    }
    if (totalHarvested[player] >= 1000 ether && !achievements[player][Achievement.MASTER_FARMER]) {
        achievements[player][Achievement.MASTER_FARMER] = true;
        achievementTimestamp[player][Achievement.MASTER_FARMER] = block.timestamp;
        emit AchievementUnlocked(player, Achievement.MASTER_FARMER, block.timestamp);
    }
}

/**
 * Game treasury management
 */
uint256 public treasuryBalance;

function withdraw() external onlyOwner {
    payable(owner).transfer(address(this).balance);
}

/**
 * Dynamic pricing
 */
function updateMintCost(uint256 newCost) external onlyOwner {
    mintCost = newCost;
}

/**
 * Game statistics
 */
struct GameStats {
    uint256 totalPlantsMinted;
    uint256 totalHarvests;
    uint256 totalGDNMinted;
    uint256 totalItemsSold;
}

function getGameStats() external view returns (GameStats memory) {
    return GameStats({
        totalPlantsMinted: plantNFT.nextTokenId(),
        totalHarvests: 0, // Would need tracking
        totalGDNMinted: gardenToken.totalSupply(),
        totalItemsSold: 0 // Would need tracking
    });
}
}