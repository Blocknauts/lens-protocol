// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import { IFollowModule } from '../../../interfaces/IFollowModule.sol';
import { ModuleBase } from '../ModuleBase.sol';
import { FollowValidatorFollowModuleBase } from './FollowValidatorFollowModuleBase.sol';
import { FeeModuleBase } from '../FeeModuleBase.sol';
import { Errors } from '../../../libraries/Errors.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

struct ProfileData {
  uint256 profileId;
  address[] currencies;
  uint256[] amounts;
}

contract AssetDepositFollowModule is IFollowModule, FollowValidatorFollowModuleBase, FeeModuleBase {
  using SafeERC20 for IERC20;

  constructor(address hub, address moduleGlobals) FeeModuleBase(moduleGlobals) ModuleBase(hub) {}

  mapping(uint256 => ProfileData) internal _dataByProfile;

  function initializeFollowModule(uint256 profileId, bytes calldata data)
    external
    override
    onlyHub
    returns (bytes memory)
  {
    (uint256[] memory amounts, address[] memory currencies) = abi.decode(data, (uint256[], address[]));
    if(amounts.length != currencies.length)
      revert Errors.InitParamsInvalid();

    for(uint256 i = 0; i < currencies.length; i++) {
      address currency = currencies[i];
      uint256 amount = amounts[i];

      if (!_currencyWhitelisted(currency) || amount == 0)
        revert Errors.InitParamsInvalid();
    }

    _dataByProfile[profileId] = ProfileData({
      profileId: profileId,
      currencies: currencies,
      amounts: amounts
    });

    return data;
  }

  function processFollow(
    address follower,
    uint256 profileId,
    bytes calldata // data
  ) external override onlyHub {
    ProfileData memory profileData = _dataByProfile[profileId];

    for(uint256 i = 0; i < profileData.currencies.length; i++) {
      address currency = profileData.currencies[i];
      uint256 amount = profileData.amounts[i];

      if (!_currencyWhitelisted(currency))
        revert Errors.InitParamsInvalid();
      IERC20(currency).safeTransferFrom(follower, address(this), amount);
    }
  }

  function followModuleTransferHook(
    uint256 profileId,
    address from,
    address to,
    uint256 // followNFTTokenId
  ) external override {
    if(to == address(0)) {
      ProfileData memory profileData = _dataByProfile[profileId];
      (address treasury, uint16 treasuryFee) = _treasuryData();

      // Transfer each currency to the address burning the NFT
      for(uint256 i = 0; i < profileData.currencies.length; i++) {
        address currency = profileData.currencies[i];
        uint256 amount = profileData.amounts[i];
        uint256 treasuryAmount = (amount * treasuryFee) / BPS_MAX;
        uint256 adjustedAmount = amount - treasuryAmount;

        IERC20(currency).safeTransfer(from, adjustedAmount);
        if(treasuryAmount > 0)
          IERC20(currency).safeTransfer(treasury, treasuryAmount);
      }
    }
  }

  function getProfileData(uint256 profileId) external view returns (ProfileData memory) {
        return _dataByProfile[profileId];
    }

}
