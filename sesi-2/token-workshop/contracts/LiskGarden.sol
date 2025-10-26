// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract LiskGarden {

    enum GrowthStage { SEED, SPROUT, GROWING, BLOOMING }

    struct Plant {
        uint256 id;
        address owner;
        GrowthStage stage;
        uint256 plantedDate;
        uint256 lastWatered;
        uint8 waterLevel;
        bool exists;
        bool isDead;
    }

    mapping(uint256 => Plant) public plants;
    mapping(address => uint256[]) public userPlants;
    uint256 public plantCounter;
    address public owner;


    uint256 public constant PLANT_PRICE = 0.0000001 ether;
    uint256 public constant HARVEST_REWARD = 0.0003 ether;
    uint256 public constant STAGE_DURATION = 1 minutes;
    uint256 public constant WATER_DEPLETION_TIME = 30 seconds;
    uint8 public constant WATER_DEPLETION_RATE = 2;


    event PlantSeeded(address indexed owner, uint256 indexed plantId);
    event PlantWatered(uint256 indexed plantId, uint8 newWaterLevel);
    event PlantHarvested(uint256 indexed plantId, address indexed owner, uint256 reward);
    event StageAdvanced(uint256 indexed plantId, GrowthStage newStage);
    event PlantDied(uint256 indexed plantId);
    event Funded(address indexed sender, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    function plantSeed() external payable returns (uint256) {
        require(msg.value >= PLANT_PRICE, "Insufficient payment for planting");

        plantCounter += 1;
        uint256 newId = plantCounter;

        Plant memory p = Plant({
            id: newId,
            owner: msg.sender,
            stage: GrowthStage.SEED,
            plantedDate: block.timestamp,
            lastWatered: block.timestamp,
            waterLevel: 100,
            exists: true,
            isDead: false
        });

        plants[newId] = p;
        userPlants[msg.sender].push(newId);

        emit PlantSeeded(msg.sender, newId);
        
        return newId;
    }

    function calculateWaterLevel(uint256 plantId) public view returns (uint8) {
        Plant memory p = plants[plantId];
        if (!p.exists || p.isDead) {
            return 0;
        }

        if (p.waterLevel == 0) {
            return 0;
        }

        uint256 timeSinceWatered = block.timestamp - p.lastWatered;
        uint256 depletionIntervals = timeSinceWatered / WATER_DEPLETION_TIME;
        uint256 waterLost = depletionIntervals * uint256(WATER_DEPLETION_RATE);

        if (waterLost >= uint256(p.waterLevel)) {
            return 0;
        }

        uint256 current = uint256(p.waterLevel) - waterLost;
        return uint8(current);
    }

    function updateWaterLevel(uint256 plantId) internal {
        Plant storage p = plants[plantId];
        if (!p.exists) return;

        uint8 currentWater = calculateWaterLevel(plantId);

        if (p.waterLevel != currentWater) {
            p.waterLevel = currentWater;
        }

        if (currentWater == 0 && !p.isDead) {
            p.isDead = true;
            emit PlantDied(plantId);
        }
    }

    function waterPlant(uint256 plantId) external {
        Plant storage p = plants[plantId];
        require(p.exists, "Plant does not exist");
        require(p.owner == msg.sender, "Not the owner");
        require(!p.isDead, "Plant is dead");

        p.waterLevel = 100;
        p.lastWatered = block.timestamp;

        emit PlantWatered(plantId, p.waterLevel);

        updatePlantStage(plantId);
    }

    function updatePlantStage(uint256 plantId) public {
        Plant storage p = plants[plantId];
        require(p.exists, "Plant does not exist");

        updateWaterLevel(plantId);

        if (p.isDead) {
            return;
        }

        uint256 timeSincePlanted = block.timestamp - p.plantedDate;
        GrowthStage oldStage = p.stage;
        GrowthStage newStage = oldStage;

        if (timeSincePlanted >= 3 * STAGE_DURATION) {
            newStage = GrowthStage.BLOOMING;
        } else if (timeSincePlanted >= 2 * STAGE_DURATION) {
            newStage = GrowthStage.GROWING;
        } else if (timeSincePlanted >= 1 * STAGE_DURATION) {
            newStage = GrowthStage.SPROUT;
        } else {
            newStage = GrowthStage.SEED;
        }

        if (newStage != oldStage) {
            p.stage = newStage;
            emit StageAdvanced(plantId, newStage);
        }
    }

    function harvestPlant(uint256 plantId) external {
        Plant storage p = plants[plantId];
        require(p.exists, "Plant does not exist");
        require(p.owner == msg.sender, "Not the owner");
        require(!p.isDead, "Plant is dead");

        updatePlantStage(plantId);
        require(p.stage == GrowthStage.BLOOMING, "Plant is not blooming yet");

        p.exists = false;

        uint256 reward = HARVEST_REWARD;
        uint256 bal = address(this).balance;
        if (bal == 0) {
            revert("Contract has no funds for reward");
        }
        if (bal < reward) {
            reward = bal;
        }

        emit PlantHarvested(plantId, msg.sender, reward);

        (bool success, ) = payable(msg.sender).call{value: reward}("");
        require(success, "Reward transfer failed");
    }

    function fund() external payable {
        require(msg.value > 0, "Must send funds");
        emit Funded(msg.sender, msg.value);
    }

    function getPlant(uint256 plantId) external view returns (Plant memory) {
        Plant memory plant = plants[plantId];
        plant.waterLevel = calculateWaterLevel(plantId);
        return plant;
    }

    function getUserPlants(address user) external view returns (uint256[] memory) {
        return userPlants[user];
    }

    function withdraw() external {
        require(msg.sender == owner, "Bukan owner");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer gagal");
    }

    receive() external payable {}
}
