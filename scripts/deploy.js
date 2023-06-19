async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("PanaromaswapV1Router02");
  const token = await Token.deploy('0xc94648E6A491f114C2EBfCDEb453D004440cEC6e',
    '0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889',
    '0x1a90D089D2cb0F30fDCe5946B169ABaF601568d9',
    '0x21aaF103DF69B5FBBccc9B399c3Eb7aae5C38EF0',
    '0xbB97C5bf135C3dbCEA5E79e1E79AaE7739d6d502',
    '0x3785075F3A6721cdB9500c7547e1fac0fAf6B280',
    '0x105Ff7271200719226D83802aF77B20614681238');

  // const Token = await ethers.getContractFactory("lockRouter");
  // const token = await Token.deploy('0xc94648E6A491f114C2EBfCDEb453D004440cEC6e', '0x2c9efe06de3f5f758348F1F39472Ff4a3F37FeB7');

  // const Token = await ethers.getContractFactory("PanaromaswapV1LockFactory");
  // const token = await Token.deploy('0xc94648E6A491f114C2EBfCDEb453D004440cEC6e');
  ///WMATIC: 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889
  ///WETH9(GOERLI): 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
  ///WETH(OPTIMIST): 0x4200000000000000000000000000000000000006
  ///WETH(ARBITRUM): 0xe39Ab88f8A4777030A534146A9Ca3B52bd5D43A3 
  console.log("Token address:", token.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });