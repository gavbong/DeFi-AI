import { isAddress } from "ethers";
export function mustAddr(v: string | undefined, name: string): string {
  if (!v) throw new Error(`Missing env ${name}`);
  if (!isAddress(v)) throw new Error(`Env ${name} is not a valid 0x address: ${v}`);
  return v;
}
