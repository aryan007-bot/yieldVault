let provider = new ethers.providers.Web3Provider(window.ethereum)
let signer = provider.getSigner('0xd949fb6C12B7aDC6F762c7425B582A880210e0d6')
let targetAddress = "0x6cf050C2aFC6ed386d805629Ef815A9839292277";
const targetABI = [
    "function name() public view returns (string)",
    "function totalAssets() public view returns (uint256)",
    "function deposit(uint256 assets, address receiver) public returns (uint256 shares)",
    "function withdraw(uint256 assets, address receiver, address owner) public returns (uint256 shares)",
    "function supplyToAaveV3(uint256 amount) public",
    "function withdrawFromAaveV3() public returns(uint256)"
]
const Vault = new ethers.Contract(targetAddress,targetABI,provider);
const DAIaddress = "0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357";
let DAI_ABI = [
    "function approve(address spender, uint256 amount) public returns (bool)"
]
const DAI = new ethers.Contract(DAIaddress,DAI_ABI,provider)
let nonce=0;

async function connectMetamask() {
    try {
        await provider.send("eth_requestAccounts", []);
        console.log(`signer login: ${await signer.getAddress()}`);
    }catch(error){
        console.log(`this is the error : ${error}`);
    }
}

async function getName() {
    const nameit = await Vault.name();
    console.log(`${nameit}`);
    document.getElementById("printName").innerHTML = nameit;
}

async function getTotalAssets(){
    const assets = await Vault.totalAssets();
    document.getElementById("printAssets").innerHTML = assets;
    console.log(`${assets}`);
}


// encountering error here when doing both approve and deposit, need to think of a way doing in a single tx.
async function deposit() {
    const amt = document.getElementById('d_assets').value;
    const receiver = document.getElementById('d_receiver').value;
    await DAI.connect(signer).approve(targetAddress,amt);
    await Vault.connect(signer).deposit(amt,receiver);
    document.getElementById('d_nonce').innerHTML = `nonce: ${++nonce}`;
}

async function withdraw() {
    const amt = document.getElementById('w_assets').value;
    const receiver = document.getElementById('w_receiver').value;
    const owner = document.getElementById('w_owner').value;
    await Vault.connect(signer).withdraw(amt,receiver,owner);
    document.getElementById('w_nonce').innerHTML = `nonce: ${++nonce}`;
}

async function supplyToAaveV3() {
    await Vault.connect(signer).supplyToAaveV3(document.getElementById('supplyAmt').value);
    document.getElementById('supplyNonce').innerHTML = `nonce: ${++nonce}`;
}

async function withdrawFromAaveV3() {
    await Vault.connect(signer).withdrawFromAaveV3();
    document.getElementById('withdrawNonce').innerHTML = `nonce: ${++nonce}`;
}