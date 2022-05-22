import { assert } from 'console';
import { defaultAbiCoder } from 'ethers/lib/utils';
import { task } from 'hardhat/config';
import {
  FollowNFT__factory,
  LensHub__factory,
  AssetDepositFollowModule__factory,
  Currency__factory,
} from '../typechain-types';
import { CreateProfileDataStruct } from '../typechain-types/LensHub';
import {
  waitForTx,
  initEnv,
  getAddrs,
  ProtocolState,
  ZERO_ADDRESS,
  deployContract,
} from './helpers/utils';

task('test-asset-deposit-follow-module', 'Tests the AssetDepositFollowModule')
  .setAction(async ({}, hre) => {
    const [governance, , user] = await initEnv(hre);
    const addrs = getAddrs();
    const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);

    await waitForTx(lensHub.setState(ProtocolState.Unpaused));
    await waitForTx(lensHub.whitelistProfileCreator(user.address, true));

    const inputStruct: CreateProfileDataStruct = {
      to: user.address,
      handle: 'tester',
      imageURI:
        'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
      followModule: ZERO_ADDRESS,
      followModuleInitData: [],
      followNFTURI:
        'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
    };
    await waitForTx(lensHub.connect(user).createProfile(inputStruct));

    const assetDepositFollowModule = await deployContract(
      new AssetDepositFollowModule__factory(governance).deploy(lensHub.address, addrs['module globals'])
    );
    await waitForTx(lensHub.whitelistFollowModule(assetDepositFollowModule.address, true));

    const data = defaultAbiCoder.encode(
      ['uint256[]', 'address[]'],
      [['100', '200'], [addrs['currency'], addrs['currency']]]
    );
    await waitForTx(lensHub.connect(user).setFollowModule(1, assetDepositFollowModule.address, data))

    const currency = Currency__factory.connect(addrs['currency'], user);
    await waitForTx(currency.mint(user.address, 1000));
    
    await currency.approve(assetDepositFollowModule.address, 300);
    await waitForTx(lensHub.connect(user).follow([1], [data]));
    console.log((await currency.balanceOf(user.address)).toNumber());

    const followNFTAddr = await lensHub.getFollowNFT(1);
    const followNFT = FollowNFT__factory.connect(followNFTAddr, user);

    await followNFT.burn(1);
    console.log((await currency.balanceOf(user.address)).toNumber());

});
