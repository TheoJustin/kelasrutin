# LiskGarden - Token Ecosystem

## Overview

LiskGarden is a comprehensive blockchain-based farming game built on Lisk Sepolia testnet. The ecosystem consists of four interconnected smart contracts that create a complete gaming experience with tokenomics, NFTs, and game items. Players can plant seeds, grow plants, use items to enhance growth, and harvest rewards in the form of GDN tokens.

The implementation features a multi-token architecture with ERC-20 rewards, ERC-721 plant NFTs, ERC-1155 game items, and a main orchestration contract that ties everything together with achievements, leaderboards, and game mechanics.

## Contracts

### GardenToken (ERC-20)
- Address: 0xEdC46A754886cf4b7a868573a29EA32e73B67151
- Blockscout: https://sepolia-blockscout.lisk.com/address/0xEdC46A754886cf4b7a868573a29EA32e73B67151
- Features:
  - Mintable reward tokens for plant harvesting
  - Daily minting limits to control inflation
  - Burn mechanism with minimum burn amounts
  - Circulating supply tracking
  - Reward calculation based on plant rarity and stage
  - Access control for game contract minting

### PlantNFT (ERC-721)
- Address: 0xeff6fAd56944007CC65Cd444881EB482Cc868A57
- Blockscout: https://sepolia-blockscout.lisk.com/address/0xeff6fAd56944007CC65Cd444881EB482Cc868A57
- Features:
  - Unique plant NFTs with metadata (name, species, rarity, stage)
  - Growth mechanics with watering and time requirements
  - 5-tier rarity system (1-5 stars)
  - 3-stage growth progression (seedling → mature → harvestable)
  - Watering cooldown system (8 hours between waterings)
  - Harvest rewards based on rarity and maturity
  - Integration with game items for enhanced growth

### GameItems (ERC-1155)
- Address: 0x5E48847025335a212D45430d18F040288C70df89
- Blockscout: https://sepolia-blockscout.lisk.com/address/0x5E48847025335a212D45430d18F040288C70df89
- Features:
  - Multi-token standard for various game items
  - Fertilizer (instant growth boost)
  - Growth Boost items (timed multipliers: 1H, 2H)
  - Consumable item system with automatic burning
  - Active boost tracking with expiration times
  - Batch item usage functionality
  - Usage statistics and leaderboards
  - Effective growth rate calculations

### LiskGarden (Main Game)
- Address: 0x574BD7CC08444E1f2CA30B2D8450437476B32f16
- Blockscout: https://sepolia-blockscout.lisk.com/address/0x574BD7CC08444E1f2CA30B2D8450437476B32f16
- Features:
  - Central game orchestration contract
  - Plant seeding with ETH payment (0.001 ETH default)
  - Achievement system (First Plant, Tenth Plant, Master Farmer)
  - Player statistics tracking (plants owned, total harvested)
  - Batch harvesting functionality
  - Leaderboard system for top farmers
  - Dynamic pricing controls
  - Treasury management for collected fees
  - Game statistics aggregation

## Setup & Testing

```bash
# Install dependencies
npm install

# Run all tests
npx hardhat test

# Run specific contract tests
npx hardhat test --grep "GameItems"
npx hardhat test --grep "GardenToken"
npx hardhat test --grep "PlantNFT"
npx hardhat test --grep "LiskGarden"

# Generate test coverage report
npx hardhat coverage

# Compile contracts
npx hardhat compile

# Deploy to Lisk Sepolia
npx hardhat ignition deploy ignition/modules/DeployAll.ts --network lisk-sepolia
```

## Game Mechanics

### Plant Lifecycle
1. **Seeding**: Pay 0.001 ETH to mint a plant NFT with random rarity
2. **Watering**: Water plants every 8+ hours (3 waterings required per stage)
3. **Growing**: After 1 day + 3 waterings, plants can advance to next stage
4. **Harvesting**: Stage 3 plants can be harvested for GDN token rewards

### Item System
- **Fertilizer**: Instant growth boost (if growth requirements are met)
- **Growth Boost 1H**: 3x growth multiplier for 1 hour
- **Growth Boost 2H**: 5x growth multiplier for 2 hours
- Items are consumable and burned after use

### Achievement System
- **First Plant**: Unlocked when planting your first seed
- **Tenth Plant**: Unlocked when owning 10 plants
- **Master Farmer**: Unlocked when harvesting 1000+ GDN tokens

## Architecture

The contracts are designed with clear separation of concerns:

- **GardenToken**: Handles all token economics and rewards
- **PlantNFT**: Manages plant lifecycle and growth mechanics  
- **GameItems**: Provides enhancement items and boost systems
- **LiskGarden**: Orchestrates gameplay and tracks achievements

All contracts include comprehensive access controls, event emissions for frontend integration, and gas-optimized implementations.

## Test Coverage

The project includes 63 comprehensive tests covering:
- Contract deployment and initialization
- Token minting, burning, and transfers
- Plant growth mechanics and lifecycle
- Item usage and boost calculations
- Achievement unlocking and tracking
- Access control and security measures
- Edge cases and error conditions

## Development

Built with:
- Solidity 0.8.30
- Hardhat development framework
- OpenZeppelin contracts for security
- Viem for testing and deployment
- TypeScript for type safety

## License

MIT License