# pce
Plasma Interface contracts

## Root chain
Contains Plasma contract to be deployed in root chain (Ethereum Mainnet)
### Develop
```
cd root_chain
npm install
```
### Test
With ganache in port 7545:
```
npx truffle test --n
```

## Child chain
Contains Plasma contract to be deployed in child chain (any EVM-compatible chain)
