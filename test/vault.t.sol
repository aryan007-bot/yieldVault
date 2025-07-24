// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "src/Vault.sol";

import "openzeppelin/token/ERC20/IERC20.sol";
import "aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import "aave-v3-core/interfaces/IPool.sol";


contract vaultTest is Test {
    Certificate public c;
    Vault_v1_DAI_AAVE public v1_impl;
    Vault_v2_DAI_AAVE public v2_impl;
    Beacon public b;
    Vault_Proxy public vp;
    Factory_Vault_Proxy public f;
    address public deployer = 0xd949fb6C12B7aDC6F762c7425B582A880210e0d6;
    address public dai = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
    address public addressProvider = 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A;
    uint256 sepoliaFork;

    address public alice = vm.addr(1);
    address public bob = vm.addr(2);

    function setUp() public {
        sepoliaFork = vm.createFork("https://sepolia.infura.io/v3/f9f12ceb3d56436aaf50ff3800a10856");
        vm.selectFork(sepoliaFork);
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(deployer, "deployer");
        vm.label(dai, "dai");
        vm.label(addressProvider, "addressProvider");

        //-----------DEPLOYMENTS------------//
        vm.startPrank(deployer);
        c = new Certificate(); c.initialize();
        vm.label(address(c), "c");
        
        v1_impl = new Vault_v1_DAI_AAVE();
        v1_impl.initialize("Vault_v1_DAI_AAVE", "V1", address(c));
        vm.label(address(v1_impl), "Vault_v1_DAI_AAVE");

        v2_impl = new Vault_v2_DAI_AAVE();
        vm.label(address(v2_impl), "Vault_v2");

        b = new Beacon(address(v1_impl),deployer);
        vm.label(address(b), "b");

        vp = new Vault_Proxy(address(b),"");
        vm.label(address(vp), "vp");

        f = new Factory_Vault_Proxy(payable(address(vp)));
        vm.label(address(f), "f");

        (bool gotit,) = dai.call(abi.encodeWithSignature("transfer(address,uint256)",alice,1000e18));
        require(gotit);
    }

    function test_aliceCreatesAndInitializesVault() public {
        //alice creates vault --------------------------------------------------//
        vm.startPrank(alice);
        address v_alice = f.getNewVault();
        vm.label(v_alice, "v_alice");

        //alice initializes vault ----------------------------------------------//
        (bool initialized,) = v_alice.call(abi.encodeWithSignature(
            "initialize(string,string,address)",
            "Vault_v1",
            "V1",
            address(c)
        ));
        require(initialized,"initialization failed");

        //assert vault name ----------------------------------------------------//
        (,bytes memory data) = v_alice.call(abi.encodeWithSignature("name()"));
        string memory name = abi.decode(data,(string));
        assertEq(name, "Vault_v1");
    }

    function test_aliceDepositAndSupply() public {
        //alice creates vault --------------------------------------------------//
        vm.startPrank(alice);
        address v_alice = f.getNewVault();
        vm.label(v_alice, "v_alice");

        //alice initializes vault ----------------------------------------------//
        (bool initialized,) = v_alice.call(abi.encodeWithSignature(
            "initialize(string,string,address)",
            "Vault_v1",
            "V1",
            address(c)
        ));
        require(initialized,"initialization failed");

        //alice deposits 15 dai into her vault ---------------------------------//
        IERC20(dai).approve(address(v_alice), 15e18);
        (bool deposit,) = v_alice.call(abi.encodeWithSignature("deposit(uint256,address)",15e18,alice));
        require(deposit);
        (,bytes memory assets_in_Vault) = v_alice.call(abi.encodeWithSignature("totalAssets()"));
        assertEq(abi.decode(assets_in_Vault,(uint256)), 15e18);

        //alice spends the vault assets at aave for generating yield ----------//
        (bool supply,) = v_alice.call(abi.encodeWithSignature("supplyToAaveV3(uint256)",15e18));
        require(supply);        
        (,bytes memory assets_in_Vault2) = v_alice.call(abi.encodeWithSignature("totalAssets()"));
        assertEq(abi.decode(assets_in_Vault2,(uint256)), 0);
        vm.stopPrank();
    }

    function test_aliceGotCertificateOnDeposit() public {
        //alice creates vault --------------------------------------------------//
        vm.startPrank(alice);
        address v_alice = f.getNewVault();
        vm.label(v_alice, "v_alice");

        //alice initializes vault ----------------------------------------------//
        (bool initialized,) = v_alice.call(abi.encodeWithSignature(
            "initialize(string,string,address)",
            "Vault_v1",
            "V1",
            address(c)
        ));
        require(initialized,"initialization failed");

        //alice deposits 15 dai into her vault ---------------------------------//
        IERC20(dai).approve(address(v_alice), 15e18);
        (bool deposit,) = v_alice.call(abi.encodeWithSignature("deposit(uint256,address)",15e18,alice));
        require(deposit);
        (,bytes memory assets_in_Vault) = v_alice.call(abi.encodeWithSignature("totalAssets()"));
        assertEq(abi.decode(assets_in_Vault,(uint256)), 15e18);

        //assert that alice got certificate of deposition
        assertEq(c.balanceOf(alice), 1);
        assertEq(c.ownerOf(0), alice);
        assertEq(c.tokenURI(0),"database/0");
    }

    function test_deployerUpgradedImplementation_AliceHasUpgradedLogic() public {
        //alice creates vault --------------------------------------------------//
        vm.startPrank(alice);
        address v_alice = f.getNewVault();
        vm.label(v_alice, "v_alice");

        //alice initializes v_alice --------------------------------------------//
        (bool initialized,) = v_alice.call(abi.encodeWithSignature(
            "initialize(string,string,address)",
            "Vault_v1",
            "V1",
            address(c)
        ));
        require(initialized,"initialization failed");

        //assert vault name ----------------------------------------------------//
        (,bytes memory data) = v_alice.call(abi.encodeWithSignature("name()"));
        string memory name = abi.decode(data,(string));
        assertEq(name, "Vault_v1");   
        vm.stopPrank();

        //deployer upgrades Vault_v1_DAI_AAVE to Vault_v2_DAI_AAVE -------------//
        vm.prank(deployer);
        b.upgradeTo(address(v2_impl));

        //assert value of x in Vault_v2_DAI_AAVE ------------------------------//
        vm.prank(alice);
        (bool xSet,) = v_alice.call(abi.encodeWithSignature("setX(uint256)",75));
        require(xSet);

        (,bytes memory data1) = v_alice.call(abi.encodeWithSignature("x()"));
        uint256 x = abi.decode(data1,(uint256));
        assertEq(x, 75);  
    }

}