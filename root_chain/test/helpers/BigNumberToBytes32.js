function padToBytes32(n) {
  while (n.length < 64) {
    n = "0" + n;
  }
  return "0x" + n;
}

export default function BN2B32(bn) {
  return padToBytes32(bn.toString(16));
}
