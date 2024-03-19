---
title: "Tcp1pctf smartcontract"
date: 2023-10-16T00:00:00+08:00
---

Since I am learning blockchain security recently, I found this competition to try out on my own over the weekend. These questions were very educational (not hard) and I also learned something. But due to other local ctfs and a few things I didn't quite get into it. 

## Venue

```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Venue{
    string private flag;
    string private message;

    constructor(string memory initialFlag, string memory initialMessage){
        flag = initialFlag;
        message = initialMessage;
    }

    function enterVenue() public view returns(string memory){
        return flag;
    }

    function goBack() public view returns(string memory){
        return message;
    }
}
```

Very concise code. This can be solved by simply calling enterVenue.

The following solving used the `web3.py` and ABI compiled by Remix.

```python
from web3 import Web3

# Instantiate the web3 object and specify the HTTP provider
w3 = Web3(Web3.HTTPProvider('https://eth-sepolia.g.alchemy.com/v2/SMfUKiFXRNaIsjRSccFuYCq8Q3QJgks8'))

# print(w3.eth.get_block('latest'))

# compiled in remix
abi = [
	{
		"inputs": [
			{
				"internalType": "string",
				"name": "initialFlag",
				"type": "string"
			},
			{
				"internalType": "string",
				"name": "initialMessage",
				"type": "string"
			}
		],
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"inputs": [],
		"name": "enterVenue",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "goBack",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	}
]

# contract address
address = '0x1AC90AFd478F30f2D617b3Cb76ee00Dd73A9E4d3'

contract_instance = w3.eth.contract(address=address, abi=abi)

func = getattr(contract_instance.functions, 'enterVenue')()
flag = func.call()
print(f"flag: {flag}")

# TCP1P{d0_3nj0y_th3_p4rty_bu7_4r3_y0u_4_VIP?}
```

## Location

```bash
====Going to The Party====

To Find the party location
You need to solve a simple riddle regarding a SLOT
Answer everything correctly, and find the exact location!

Question: In which Slot is Password Stored?

You'll answer with and ONLY WITH [numbers]
ex: 
0,1,2,3,4.....99

Note: 
    -   Slot start from 0
    -   If it doesn't stored on SLOT, answer 0

Identification Required for Guest

Question:

contract StorageChallenge7 {
    bytes32 private key;
    bytes4 private key_1;
    bytes16 private key_2;
    address private owner;
    uint256 private Token;
    address private immutable Investor;
    address private Courier;
    bytes32 private immuatble password;
}

Answer:
```

Apparently a question about EVM. The requirement is to find the index of the memory slot where the password is located.There are many articles or documents on the Internet that can be used to understand the memory allocation mechanism.

Simply put:

- The bytes type occupies the number of bytes it declares. Uint occupies the declared number of bits divided by 8. The bool type occupies 1 byte, and the address type occupies 20 bytes.

- If the free bytes in the previous slot are not enough to fill the current data, a new slot will be opened.
- Each element of the array occupies a independent slot. 
- Variables declared with immutable are not stored in memory as constants. 

There are still some types and details not covered. But enough to solve this challenge.

```py
from pwn import *
import re


def get_contract_content(stream: bytes):
    pattern = r"\{([^}]+)\}"
    match = re.search(pattern, stream.decode())
    if match:
        return match.group(1)
    else:
        raise Exception(stream.decode())
        return None


def get_type_array_till_pwd(content: string):
    line_array = content.split('\n')
    type_array = []
    for i in range(len(line_array)):
        if line_array[i] and 'immutable' not in line_array[i]:
            type_array.append(line_array[i][4:].split(' ')[0])
        if 'immutable password' in line_array[i]:
            return ['bool']
        if ' password;' in line_array[i]:
            return type_array
    raise Exception(content)
    return None


# References to https://www.8btc.com/article/6693684 (Chinese)
def get_slot_number_by_type_array(type_array: list):

    slot_number = 0
    current_slot_height = 0
        

    for type in type_array:
        if '[' in type:
            if current_slot_height > 0:
                slot_number += 1
                current_slot_height = 0
            slot_number += int(re.search(r"\[([^[\]]+)\]", type).group(1))

        if type in ['bytes32', 'uint256']:
            if current_slot_height > 0:
                slot_number += 2
                current_slot_height = 0
            else:
                slot_number += 1
                current_slot_height = 0

        if type in ['address']:
            if current_slot_height <= 12:
                current_slot_height += 20
            else:
                slot_number += 1
                current_slot_height = 20

        if type in ['bytes16', 'uint128']:
            if current_slot_height <= 16:
                current_slot_height += 16
            else:
                slot_number += 1
                current_slot_height = 16

        if type in ['bytes8', 'uint64']:
            if current_slot_height <= 24:
                current_slot_height += 8
            else:
                slot_number += 1
                current_slot_height = 8

        if type in ['bytes4', 'uint32']:
            if current_slot_height <= 28:
                current_slot_height += 4
            else:
                slot_number += 1
                current_slot_height = 4

        if type in ['bool']:
            if current_slot_height <= 31:
                current_slot_height += 1
            else:
                slot_number += 1
                current_slot_height = 1

    if current_slot_height == 0:
        return slot_number - 1
    return slot_number


if __name__ == '__main__':
    conn = remote('ctf.tcp1p.com', '20005')
    for i in range(11):
        recvd = conn.recvuntil(b'Answer: ', drop=False)
        print(get_contract_content(recvd))
        print(get_type_array_till_pwd(get_contract_content(recvd)))
        answer = get_slot_number_by_type_array(get_type_array_till_pwd(get_contract_content(recvd)))
        print(answer)
        conn.sendline(str(answer).encode())
        print('-------------------------------------------------------------------\n')

    output = conn.recvall()
    print(output.decode())

# TCP1P{W00t_w00t_t0_th3_p4rty_47JHbddc}
```

I saw that the most solutions in discord are using use compiler to simulate. Glad I learned more in it.

~~And maybe I should polish this script a little more so it can be used elsewhere~~

## VIP

```bash
Welcome to TCP1P Blockchain Challenge

1. How to 101?
2. get Contract
>> 2
Contract Addess: 0xFC5C0e4845ebb6fedcB57c17A09BFC77BE4e1478
RPC URL        : https://eth-sepolia.g.alchemy.com/v2/SMfUKiFXRNaIsjRSccFuYCq8Q3QJgks8
To start       : Simply call the help() function, everything is written there

Note: Due it's deployed on Sepolia network, please use your own Private key to do the transaction
      If you need funds, you can either DM the probset or get it on https://sepoliafaucet.com/
```

```bash
$ cast call 0x364Ca1729564bdB0cE88301FC72cbE3dCCcC08eD "help()" -r https://eth-sepolia.g.alchemy.com/v2/SMfUKiFXRNaIsjRSccFuYCq8Q3QJgks8 | cut -c3- | xxd -r -p | (cat && printf "\x0A")
 �come to TCP1P Private Club!

Enjoy the CTF Party of your life here!
But first... Please give me your id, normal people have at least member role
Of Course, there are also many VIPs over here. B-)

Functions:

Entrance(role) -> verify your role here, are you a member or VIP Class
   > role  --> input your role as string
stealVIPCode() -> someone might've just steal a vip code and want to give it to you
getFlag()      -> Once you show your role, you can try your luck! ONLY VIP Can get the Flag!
```

```bash
$ cast call 0x364Ca1729564bdB0cE88301FC72cbE3dCCcC08eD "stealVIPCode()" -r https://eth-sepolia.g.alchemy.com/v2/SMfUKiFXRNaIsjRSccFuYCq8Q3QJgks8 | cut -c3- | xxd -r -p | (cat && printf "\x0A")
 � I may or may not get you a ticket, but I don't understand much about how to decode this.
It's some sort of their abiCoder policy. 
VIP-Ticket: 0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002f5443503150317374436c61737353656174202d2069732074686520564950205469636b6574207468657920736169640000000000000000000000000000000000
```

```bash
$ echo 0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002f5443503150317374436c61737353656174202d2069732074686520564950205469636b6574207468657920736169640000000000000000000000000000000000 | cut -c3- | xxd -r -p | (cat && printf "\x0A")
 /TCP1P1stClassSeat - is the VIP Ticket they said
```

```bash
$ cast send 0x364Ca1729564bdB0cE88301FC72cbE3dCCcC08eD "Entrance(string)" -r https://eth-sepolia.g.alchemy.com/v2/SMfUKiFXRNaIsjRSccFuYCq8Q3QJgks8 --private-key <64byteskey> -- "TCP1P1stClassSeat"

blockHash               0xc3303ccb93235e2af82754e9eacff270869233faf59bec2a0c6116bd29fed9e8
blockNumber             4501630
contractAddress         
cumulativeGasUsed       2823120
effectiveGasPrice       28176596118
gasUsed                 58988
logs                    []
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
root                    
status                  1
transactionHash         0x1b244773c5abd43f3efc91b23f07b538a7d6dd927db594619557678c038bbbb1
transactionIndex        14
type                    2
```

```bash
$ cast call 0x364Ca1729564bdB0cE88301FC72cbE3dCCcC08eD "getFlag()" -r https://eth-sepolia.g.alchemy.com/v2/SMfUKiFXRNaIsjRSccFuYCq8Q3QJgks8 --private-key <64byteskey>  | cut -c3- | xxd -r -p | (cat && printf "\x0A")
 8TCP1P{4_b1t_of_f0undry_s3nd_4nd_abiCoder_w0n7_hur7_y34h}
```