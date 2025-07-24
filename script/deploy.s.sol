// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import "src/Vault.sol";

contract deployScript is Script {
    address public deployer = 0xd949fb6C12B7aDC6F762c7425B582A880210e0d6;
    address public f;
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        address v1_impl = address(new Vault_v1_DAI_AAVE());
        address b = address(new Beacon(v1_impl,deployer));
        address vp = address(new Vault_Proxy(b,""));
        f = address(new Factory_Vault_Proxy(payable(vp)));
        vm.stopBroadcast();
    }

}
