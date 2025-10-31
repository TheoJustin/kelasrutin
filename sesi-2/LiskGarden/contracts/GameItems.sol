// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./PlantNFT.sol";

contract GameItems is ERC1155 {

    /**
     * Define effects for each item type
     */
    struct ItemEffect {
        uint256 growthMultiplier;   // 100 = 1x, 200 = 2x
        uint256 rarityBoost;        // Percentage increase
        uint256 durationSeconds;    // 0 = instant, >0 = timed boost
        bool isConsumable;          // Burn after use?
    }


    PlantNFT public plantNFT;


    constructor(PlantNFT plant) ERC1155("") {
        plantNFT = plant;
        _initializeItemEffects();
    }


    mapping(uint256 => ItemEffect) public itemEffects;


    // Predefined item IDs
    uint256 public constant FERTILIZER = 1;
    uint256 public constant GROWTH_BOOST_1H = 2;

    function _initializeItemEffects() private {
        // Fertilizer: 2x growth, instant, consumable
        itemEffects[FERTILIZER] = ItemEffect(200, 0, 0, true);

        // Growth Boost 1H: 3x growth, 1 hour, consumable
        itemEffects[GROWTH_BOOST_1H] = ItemEffect(300, 0, 3600, true);

        // TODO: Add effects for all items

    }

    /**
     * Track active boosts per player per plant
     */
    struct ActiveBoost {
        uint256 itemId;
        uint256 expiryTime;
        uint256 multiplier;
    }

    mapping(address => mapping(uint256 => ActiveBoost[])) public activeBoosts;

    function getActiveBoosts(address player, uint256 plantId)
        external
        view
        returns (ActiveBoost[] memory)
    {
        // TODO: Return active (non-expired) boosts
        return activeBoosts[player][plantId];
    }

    function getEffectiveGrowthRate(address player, uint256 plantId)
        public
        returns (uint256)
    {
        // TODO: Calculate total multiplier from all active boosts
        uint256 totalMultiplier = 100;
        ActiveBoost[] storage boosts = activeBoosts[player][plantId];
        for (uint256 i = 0; i < boosts.length; i++) {
            if (block.timestamp < boosts[i].expiryTime) {
                totalMultiplier += (boosts[i].multiplier - 100);
            }
        }
        // TODO: Remove expired boosts
        for (uint256 i = 0; i < boosts.length; i++) {
            if (block.timestamp >= boosts[i].expiryTime) {
                boosts[i] = boosts[boosts.length - 1];
                boosts.pop();
                i--;
            }
        }

        return totalMultiplier;
    }


    /**
     * Use item on plant - apply effects
     */
    function useItem(uint256 plantId, uint256 itemId) public {
        // TODO: Check item balance
        require(balanceOf(msg.sender, itemId) >= 1, "Insufficient item balance");
        // TODO: Check plant ownership (call PlantNFT)
        require(plantNFT.ownerOf(plantId) == msg.sender, "Not the plant owner");
        // TODO: Apply effect based on item type

        ItemEffect memory effect = itemEffects[itemId];

        if (effect.durationSeconds > 0) {
            // Timed boost
            activeBoosts[msg.sender][plantId].push(ActiveBoost({
                itemId: itemId,
                expiryTime: block.timestamp + effect.durationSeconds,
                multiplier: effect.growthMultiplier
            }));
        } else {
            // Instant effect - call PlantNFT to apply
            plantNFT.growPlant(plantId);
        }

        // TODO: Burn if consumable
        if (effect.isConsumable) {
            _burn(msg.sender, itemId, 1);
        }

        
        itemUsageCount[itemId] += 1;
        playerItemUsage[msg.sender][itemId] += 1;

        emit ItemUsed(msg.sender, plantId, itemId, block.timestamp);
    }

    function useItemBatch(
        uint256 plantId,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external {
        // TODO: Implement batch usage for gas efficiency

        require(itemIds.length == amounts.length, "Mismatched arrays");

        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            for (uint256 j = 0; j < amount; j++) {
                useItem(plantId, itemId);
            }
        }
    }



    /**
     * Track item usage statistics
     */
    mapping(uint256 => uint256) public itemUsageCount;
    mapping(address => mapping(uint256 => uint256)) public playerItemUsage;

    event ItemUsed(
        address indexed player,
        uint256 indexed plantId,
        uint256 indexed itemId,
        uint256 timestamp
    );

    function getMostUsedItems(uint256 count)
        external
        view
        returns (uint256[] memory itemIds, uint256[] memory usageCounts)
    {
        // TODO: Return top N most used items
        uint256 totalItems = 2;

        if (count > totalItems) {
            count = totalItems;
        }

        uint256[] memory allIds = new uint256[](totalItems);
        uint256[] memory allCounts = new uint256[](totalItems);

        for (uint256 i = 0; i < totalItems; i++) {
            uint256 id = i + 1;
            allIds[i] = id;
            allCounts[i] = itemUsageCount[id];
        }

        itemIds = new uint256[](count);
        usageCounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 maxIndex = i;
            for (uint256 j = i + 1; j < totalItems; j++) {
                if (allCounts[j] > allCounts[maxIndex]) {
                    maxIndex = j;
                }
            }

            (allCounts[i], allCounts[maxIndex]) = (allCounts[maxIndex], allCounts[i]);
            (allIds[i], allIds[maxIndex]) = (allIds[maxIndex], allIds[i]);

            itemIds[i] = allIds[i];
            usageCounts[i] = allCounts[i];
        }

        return (itemIds, usageCounts);
    }

}