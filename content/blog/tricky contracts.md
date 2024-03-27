---
title: "Tricky Contracts Collection"
date: 2024-03-27T21:57:31+08:00
---

### Minimal Proxy Contract

https://eips.ethereum.org/EIPS/eip-1167



### "Minimal" Arbitrary Proxy

https://mcfx.us/posts/2022-10-11-minimal-proxy/



### Smallest Contract

https://ethereum.stackexchange.com/questions/40757/what-is-the-shortest-bytecode-that-will-publish-a-contract-with-non-zero-bytecod#answer-158733



### Self-destruct contract. One time collection

```
// evm-version: shanghai
// with opcode PUSH0

Runtime Opcodes:

PUSH0 -> SLOAD -> SELFDESTRUCT
0x5F54FF

Initialization Opcode:

1. PUSH0 -> PUSH20(addr) -> SSTORE
2. PUSH1(0x03) -> PUSH(0x??) -> PUSH0 -> CODECOPY
3. PUSH1(0x03) -> PUSH0 -> RETURN
0x5F73bebebebebebebebebebebebebebebebebebebebe55600360215F3960035FF3
```

