// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./GardenToken.sol";

interface IGameItems {
    function balanceOf(address owner, uint256 itemId) external view returns (uint256);
    function burn(address owner, uint256 itemId, uint256 amount) external;
}

contract PlantNFT is ERC721, Ownable {
    
    uint256 public nextTokenId;

    struct Plant {
        string name;
        string species;
        uint256 rarity;
        uint256 stage;
        uint256 lastWatered;
        uint256 lastGrowthTime;
    }

    event PlantMinted(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 rarity,
        string name,
        string species
    );

    event PlantGrown(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 stage
    );

    GardenToken public gardenToken;
    
    uint256 public constant MINT_COST = 0.001 ether;
    uint256 public constant STAGE_DURATION = 1 days;
    uint256 public constant WATERINGS_PER_STAGE = 3;
    uint256 public constant WATER_COOLDOWN = 8 hours;
    uint256 public constant HARVEST_COOLDOWN = 1 days;
    
    mapping(uint256 => Plant) public plants;
    mapping(uint256 => uint256) public waterCount;
    mapping(uint256 => uint256) public lastHarvestTime;
    
    address public gameItemsContract;

    event ItemUsed(
        address indexed owner,
        uint256 indexed plantId,
        uint256 indexed itemId,
        uint8 itemType
    );

    constructor(address gardenTokenAddress) ERC721("Lisk Garden Plant", "PLANT") Ownable(msg.sender) {
        gardenToken = GardenToken(gardenTokenAddress);
    }

    function mintPlant(string memory name, string memory species)
        external
        payable
        returns (uint256)
    {
        require(msg.value >= MINT_COST, "Insufficient payment");

        uint8 rarity = _calculateRarity();
        uint256 tokenId = nextTokenId++;
        
        _mint(msg.sender, tokenId);

        // Set lastWatered to 0 so that first watering doesn't require cooldown
        plants[tokenId] = Plant({
            name: name,
            species: species,
            rarity: rarity,
            stage: 1,
            lastWatered: 0,
            lastGrowthTime: block.timestamp
        });

        emit PlantMinted(msg.sender, tokenId, rarity, name, species);

        return tokenId;
    }

    function _calculateRarity() private view returns (uint8) {
        uint256 rand = uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            msg.sender,
            block.timestamp
        ))) % 100;
        
        if (rand < 60) {
            return 1;
        } else if (rand < 85) {
            return 2;
        } else if (rand < 95) {
            return 3;
        } else if (rand < 99) {
            return 4;
        }
        return 5;
    }

    function waterPlant(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the plant");
        Plant storage plant = plants[tokenId];
        
        // If lastWatered is 0, this is the first watering, so skip cooldown check
        if (plant.lastWatered != 0) {
            require(block.timestamp >= plant.lastWatered + WATER_COOLDOWN, "Watering cooldown active");
        }
        
        plant.lastWatered = block.timestamp;
        waterCount[tokenId]++;
    }

    function growPlant(uint256 tokenId) public {
        require(canGrow(tokenId), "Growth requirements not met");
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the plant");
        
        Plant storage plant = plants[tokenId];
        plant.stage++;
        waterCount[tokenId] = 0;
        plant.lastGrowthTime = block.timestamp;
        
        emit PlantGrown(msg.sender, tokenId, plant.stage);
    }

    function canGrow(uint256 tokenId) public view returns (bool) {
        Plant memory plant = plants[tokenId];
        bool timeOk = block.timestamp >= plant.lastGrowthTime + STAGE_DURATION;
        bool waterOk = waterCount[tokenId] >= WATERINGS_PER_STAGE;
        return timeOk && waterOk && (plant.stage < 3);
    }

    function harvestPlant(uint256 tokenId) external returns (uint256) {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the plant");
        Plant memory plant = plants[tokenId];
        require(plant.stage == 3, "Plant is not mature");
        
        uint256 reward = gardenToken.calculateReward(plant.rarity, plant.stage);
        gardenToken.mintReward(msg.sender, reward);
        lastHarvestTime[tokenId] = block.timestamp;

        return reward;
    }

    function setGameItemsContract(address _gameItemsContract) external onlyOwner {
        require(_gameItemsContract != address(0), "Invalid contract address");
        gameItemsContract = _gameItemsContract;
    }

    function useItemOnPlant(uint256 plantId, uint256 itemId) external {
        require(gameItemsContract != address(0), "GameItems contract not set");
        require(ownerOf(plantId) == msg.sender, "Not the owner of the plant");
        
        Plant storage plant = plants[plantId];
        require(plant.stage < 3, "Cannot use items on mature plants");
        
        IGameItems gameItems = IGameItems(gameItemsContract);
        require(gameItems.balanceOf(msg.sender, itemId) >= 1, "Insufficient item balance");
        
        uint8 itemType = uint8(itemId % 3) + 1;
        
        if (itemType == 1) {
            require(plant.stage < 3, "Plant already mature");
            plant.stage++;
            waterCount[plantId] = 0;
            plant.lastGrowthTime = block.timestamp;
        } else if (itemType == 2) {
            if (plant.rarity < 5) {
                plant.rarity++;
            }
        } else if (itemType == 3) {
            waterCount[plantId] = WATERINGS_PER_STAGE;
        }
        
        gameItems.burn(msg.sender, itemId, 1);
        emit ItemUsed(msg.sender, plantId, itemId, itemType);
    }

    function getPlant(uint256 tokenId) external view returns (Plant memory) {
        require(_ownerOf(tokenId) != address(0), "Plant does not exist");
        return plants[tokenId];
    }
}