// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";


contract GardenToken is ERC20{

    address public gameContract;
    modifier onlyGameContract() {
        require(msg.sender == gameContract, "Only game contract can call");
        _;
    }

    constructor(address _gameContract, uint256 initialSupply) ERC20("MyToken", "MTK")  {
        _mint(msg.sender, initialSupply * 10 ** decimals());
        gameContract = _gameContract;
    }


    /**
     * Calculate reward based on plant rarity & growth stage
     *
     * Formula:
     * Base reward = 10 GDN
     * Rarity multiplier:
     *   - Common (1): 1x
     *   - Rare (2): 2x
     *   - Epic (3): 3x
     *   - Legendary (4): 5x
     *   - Mythic (5): 10x
     * Growth stage multiplier:
     *   - Seed (0): 0x (no reward)
     *   - Sprout (1): 0.5x
     *   - Growing (2): 0.75x
     *   - Mature (3): 1x
     */

    function calculateReward(uint256 rarity, uint256 growthStage)
        public
        pure
        returns (uint256)
    {
        // TODO: Implement calculation
        uint256 _baseReward = 10 * 10**18;
        if(growthStage == 1){
            _baseReward = _baseReward * 1;
        }else if(growthStage == 2){
            _baseReward = _baseReward * 2;
        }else if(growthStage == 3){
            _baseReward = _baseReward * 3;
        }else if(growthStage == 4){
            _baseReward = _baseReward * 5;
        }else if(growthStage == 5){
            _baseReward = _baseReward * 10;
        }

        if(rarity == 0){
            _baseReward = 0;
        }else if(rarity == 1){
            _baseReward = (_baseReward * 50) / 100;
        }else if(rarity == 2){
            _baseReward = (_baseReward * 75) / 100;
        }else if(rarity == 3){
            _baseReward = (_baseReward * 1);
        }

        return _baseReward;
    }


    /**
     * Max supply cap: 100 million GDN
     * Daily mint limit: 10,000 GDN per day
     */
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18;
    uint256 public constant MAX_DAILY_MINT = 10_000 * 10**18;

    mapping(uint256 => uint256) public dailyMintedAmount;  // day => amount

    function mintReward(address to, uint256 amount) external onlyGameContract {
        
        // TODO: Check max supply
        require(totalSupply() + amount <= MAX_SUPPLY, "Total supply is exceeded");
        
        // TODO: Check daily limit
        uint256 dayTimestamp = block.timestamp / 1 days;
        uint256 amountMintedToday = dailyMintedAmount[dayTimestamp];
        require(amountMintedToday + amount <= MAX_DAILY_MINT, "Daily mint limit exceeded");
        
        // TODO: Mint
        dailyMintedAmount[dayTimestamp] = amountMintedToday + amount;
        _mint(to, amount);
    }

    /**
     * Burn cooldown: 1 day per user
     * Minimum burn: 10 GDN
     * Track total burned for analytics
     */
    mapping(address => uint256) public lastBurnTime;
    uint256 public totalBurned;

    function burn(uint256 amount) public {
        // TODO: Check minimum amount
        require(amount >= 10 * 10**18, "Minimum burn 10 GDN");
        // TODO: Check cooldown
        uint256 last = lastBurnTime[msg.sender];
        require(block.timestamp > last + 1 days, "Burning is allowed one day per user");
        // TODO: Burn & update stats
        lastBurnTime[msg.sender] = block.timestamp;
        totalBurned += amount;
        _burn(msg.sender, amount);
    }


    event RewardMinted(address indexed player, uint256 amount, uint8 rarity, uint256 stage);
    event TokensBurned(address indexed burner, uint256 amount, uint256 totalBurned);

    function circulatingSupply() public view returns (uint256) {
        // TODO: Return supply minus treasury
        return totalSupply() - balanceOf(gameContract);
    }

    function burnRate() public view returns (uint256) {
        // TODO: Calculate burn rate percentage
        if (totalSupply() == 0) return 0;
        return (totalBurned * 100) / totalSupply();
    }

}
