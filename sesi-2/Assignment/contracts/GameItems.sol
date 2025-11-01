// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPlantNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function growPlant(uint256 tokenId) external;
    function canGrow(uint256 tokenId) external view returns (bool);
}

contract GameItems is ERC1155, Ownable {
    
    IPlantNFT public plantNFT;
    
    struct ItemEffect {
        uint256 growthMultiplier; // 100 = 1x, 200 = 2x, etc.
        uint256 rarityBoost;
        uint256 durationSeconds; // 0 for instant items
        bool isConsumable;
    }
    
    struct ActiveBoost {
        uint256 multiplier;
        uint256 expiresAt;
    }
    
    mapping(uint256 => ItemEffect) public itemEffects;
    mapping(address => mapping(uint256 => ActiveBoost[])) public playerPlantBoosts;
    mapping(uint256 => uint256) public itemUsageCount;
    mapping(address => mapping(uint256 => uint256)) public playerItemUsage;
    
    event ItemUsed(address indexed player, uint256 indexed plantId, uint256 indexed itemId);
    
    constructor(address _plantNFT) ERC1155("") Ownable(msg.sender) {
        plantNFT = IPlantNFT(_plantNFT);
        
        // Initialize item effects
        itemEffects[1] = ItemEffect(200, 0, 0, true); // Fertilizer: instant 2x growth
        itemEffects[2] = ItemEffect(300, 0, 3600, true); // Growth Boost 1H: 3x for 1 hour
        itemEffects[3] = ItemEffect(500, 0, 7200, true); // Growth Boost 2H: 5x for 2 hours
    }
    
    // Mint function for testing
    function mint(address to, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        _mint(to, id, amount, data);
    }
    
    function useItem(uint256 plantId, uint256 itemId) public {
        require(plantNFT.ownerOf(plantId) == msg.sender, "Not the plant owner");
        require(balanceOf(msg.sender, itemId) >= 1, "Insufficient item balance");
        
        ItemEffect memory effect = itemEffects[itemId];
        require(effect.growthMultiplier > 0, "Invalid item");
        
        // Apply item effect
        if (effect.durationSeconds == 0) {
            // Instant effect - for fertilizer, just try to grow if possible
            // If growth requirements aren't met, the item still gets consumed
            // but no growth happens (this matches the expected behavior)
            if (plantNFT.canGrow(plantId)) {
                plantNFT.growPlant(plantId);
            }
        } else {
            // Timed boost
            playerPlantBoosts[msg.sender][plantId].push(ActiveBoost({
                multiplier: effect.growthMultiplier,
                expiresAt: block.timestamp + effect.durationSeconds
            }));
        }
        
        // Burn the item
        if (effect.isConsumable) {
            _burn(msg.sender, itemId, 1);
        }
        
        // Track usage
        itemUsageCount[itemId]++;
        playerItemUsage[msg.sender][itemId]++;
        
        emit ItemUsed(msg.sender, plantId, itemId);
    }
    
    function useItemBatch(
        uint256 plantId,
        uint256[] calldata itemIds,
        uint256[] calldata amounts
    ) external {
        require(itemIds.length == amounts.length, "Mismatched arrays");
        
        for (uint256 i = 0; i < itemIds.length; i++) {
            for (uint256 j = 0; j < amounts[i]; j++) {
                useItem(plantId, itemIds[i]);
            }
        }
    }
    
    function getActiveBoosts(address player, uint256 plantId)
        external
        view
        returns (ActiveBoost[] memory)
    {
        ActiveBoost[] memory allBoosts = playerPlantBoosts[player][plantId];
        uint256 activeCount = 0;
        
        // Count active boosts
        for (uint256 i = 0; i < allBoosts.length; i++) {
            if (allBoosts[i].expiresAt > block.timestamp) {
                activeCount++;
            }
        }
        
        // Create array of active boosts
        ActiveBoost[] memory activeBoosts = new ActiveBoost[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allBoosts.length; i++) {
            if (allBoosts[i].expiresAt > block.timestamp) {
                activeBoosts[index] = allBoosts[i];
                index++;
            }
        }
        
        return activeBoosts;
    }
    
    function getEffectiveGrowthRate(address player, uint256 plantId)
        external
        view
        returns (uint256)
    {
        ActiveBoost[] memory allBoosts = playerPlantBoosts[player][plantId];
        uint256 totalMultiplier = 100; // Base 1x
        
        for (uint256 i = 0; i < allBoosts.length; i++) {
            if (allBoosts[i].expiresAt > block.timestamp) {
                // Add the boost multiplier minus base (100)
                totalMultiplier = totalMultiplier + allBoosts[i].multiplier - 100;
            }
        }
        
        return totalMultiplier;
    }
    
    function getMostUsedItems(uint256 limit)
        external
        view
        returns (uint256[] memory itemIds, uint256[] memory usageCounts)
    {
        // Simple implementation - in production you'd want a more efficient sorting
        uint256[] memory tempIds = new uint256[](limit);
        uint256[] memory tempCounts = new uint256[](limit);
        
        // Check first few item IDs (1-10)
        for (uint256 itemId = 1; itemId <= 10; itemId++) {
            uint256 count = itemUsageCount[itemId];
            
            // Insert into sorted arrays
            for (uint256 i = 0; i < limit; i++) {
                if (count > tempCounts[i]) {
                    // Shift elements
                    for (uint256 j = limit - 1; j > i; j--) {
                        tempIds[j] = tempIds[j - 1];
                        tempCounts[j] = tempCounts[j - 1];
                    }
                    tempIds[i] = itemId;
                    tempCounts[i] = count;
                    break;
                }
            }
        }
        
        return (tempIds, tempCounts);
    }
}