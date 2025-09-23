import { generatePrivateKey, privateKeyToAddress } from "viem/accounts";

export function getRandomPubKey() {
  const privateKey = generatePrivateKey();
  const publicKey = privateKeyToAddress(privateKey);
  return publicKey;
}
