// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "openzeppelin-up/token/ERC20/extensions/ERC4626Upgradeable.sol"; 
import "openzeppelin-up/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-up/token/ERC721/ERC721Upgradeable.sol";

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/interfaces/IERC4626.sol";

import "openzeppelin-up/access/OwnableUpgradeable.sol";
import "openzeppelin/utils/ReentrancyGuard.sol";

import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin/proxy/Clones.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "aave-v3-core/interfaces/IPool.sol";
import "aave-v3-core/interfaces/IPoolAddressesProvider.sol";


/**
 * @dev Certificate deployed in preparation for Vault_v1
 */
contract Certificate is ERC721Upgradeable {
    uint256 public id;
    mapping(address => bool) public depositUsed;

    //--------- INITIALIZE YOUR CLONE -----------//
    function initialize() public initializer {
        __ERC721_init("Certificate of Deposition","CD");
    }

    //@note add data storage URL here
    function _baseURI() internal pure override returns (string memory) {
        return "database/";
    }

    function mint(address _depositor) public {
        depositUsed[_depositor] = true;
        _safeMint(_depositor,id);
        id++;
    }
}

/**
 * @dev implementation deployed first
 */
contract Vault_v1_DAI_AAVE is ERC4626Upgradeable,OwnableUpgradeable {

    IPoolAddressesProvider public POOL_PROVIDER; //0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A
    IPool public POOL;
    Certificate public certificate;

    function _authorizeUpgrade(address newImplementation) internal {}  


    //--------- INITIALIZE YOUR CLONE -----------//
    function initialize(
        string memory _name,
        string memory _symbol,
        address _certificate
    ) public initializer {
        __ERC4626_init(IERC20(0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357));//DAI asset
        __ERC20_init(_name,_symbol);
        __Ownable_init(msg.sender);
        POOL_PROVIDER = IPoolAddressesProvider(0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A);
        POOL = IPool(POOL_PROVIDER.getPool());
        certificate = Certificate(_certificate);
    }

    //---------- MODIFIED VAULT METHODS ----------//
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(msg.sender, receiver, assets, shares);

        if (!certificate.depositUsed(msg.sender)) {
            certificate.mint(msg.sender);
        }
        return shares;
    }

    //--------------- YIELD SOURCE --------------//
    function supplyToAaveV3(uint256 amount) public onlyOwner {
        //approve POOL to collect assets from vault.
        SafeERC20.safeIncreaseAllowance(IERC20(asset()), address(POOL), amount);
        POOL.supply(address(asset()), amount, address(this), 0);
    }

    function withdrawFromAaveV3() public onlyOwner returns(uint256) {
        return POOL.withdraw(address(asset()), type(uint).max, address(this));
    }

}

contract Vault_v2_DAI_AAVE is ERC4626Upgradeable,OwnableUpgradeable {

    IPoolAddressesProvider public POOL_PROVIDER; //0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A
    IPool public POOL;
    Certificate public certificate;
    uint256 public x;

    function _authorizeUpgrade(address newImplementation) internal {}  

    //----------- NEWLY ADDED METHODS ------------//
    function setX(uint256 _amt) public onlyOwner {
        x = _amt;
    }

    //---------- MODIFIED VAULT METHODS ----------//
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(msg.sender, receiver, assets, shares);

        if (!certificate.depositUsed(msg.sender)) {
            certificate.mint(msg.sender);
        }
        return shares;
    }

    //--------------- YIELD SOURCE --------------//
    function supplyToAaveV3(uint256 amount) public onlyOwner {
        //approve POOL to collect assets from vault.
        SafeERC20.safeIncreaseAllowance(IERC20(asset()), address(POOL), amount);
        POOL.supply(address(asset()), amount, address(this), 0);
    }

    function withdrawFromAaveV3() public onlyOwner returns(uint256) {
        return POOL.withdraw(address(asset()), type(uint).max, address(this));
    }

}

/**
 * @dev beacon has implementation address
 */
contract Beacon is UpgradeableBeacon {

    constructor(
        address implementation_, 
        address initialOwner
    ) UpgradeableBeacon(implementation_,initialOwner) {}

}

/**
 * @dev proxy has beacon on BeaconSlot
 */
contract Vault_Proxy is BeaconProxy {

    constructor(
        address beacon_, 
        bytes memory data_
    ) BeaconProxy(beacon_,data_) {}

}

/**
 * @dev factory clones proxy
 */
contract Factory_Vault_Proxy {

    using Clones for address;
    Vault_Proxy internal v;

    constructor(address payable Proxy_) {
        v = Vault_Proxy(Proxy_);
    }

    function getNewVault() public returns(address) {
        return address(v).clone();
    }

}
