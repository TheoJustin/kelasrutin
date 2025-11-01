# Deployment Guide

This file contains deployment information for the LiskGarden token ecosystem.

## Deployment Status

Contracts have been deployed to Lisk Sepolia testnet.

For detailed contract addresses and information, see the main README.md file.

## Deployment Commands

```bash
# Deploy all contracts
npx hardhat ignition deploy ignition/modules/DeployAll.ts --network lisk-sepolia

# Deploy individual contracts
npx hardhat ignition deploy ignition/modules/GardenToken.ts --network lisk-sepolia
npx hardhat ignition deploy ignition/modules/PlantNFT.ts --network lisk-sepolia
npx hardhat ignition deploy ignition/modules/GameItems.ts --network lisk-sepolia
npx hardhat ignition deploy ignition/modules/LiskGarden.ts --network lisk-sepolia
```

## Network Configuration

- Network: Lisk Sepolia
- Chain ID: 4202
- RPC URL: https://rpc.sepolia-api.lisk.com
- Block Explorer: https://sepolia-blockscout.lisk.com/

## Deployed Addresses

- DeployAllModule#GardenToken - 0xEdC46A754886cf4b7a868573a29EA32e73B67151
- DeployAllModule#PlantNFT - 0xeff6fAd56944007CC65Cd444881EB482Cc868A57
- DeployAllModule#GameItems - 0x5E48847025335a212D45430d18F040288C70df89
- DeployAllModule#LiskGarden - 0x574BD7CC08444E1f2CA30B2D8450437476B32f16