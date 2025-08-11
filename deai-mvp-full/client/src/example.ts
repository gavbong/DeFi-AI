
import { Wallet } from "ethers";
async function main(){
  const w = Wallet.createRandom();
  console.log("Wallet:", await w.getAddress());
}
main();
