---
title: "Foundry forge script 一二事。some details that need attention"
date: 2024-07-18T17:40:59+08:00
---



​	不久前 All solve了 [ONLYPWNER](https://onlypwner.xyz) 靶场，Rank 10。期间遇到了不少因为`forge`特性而导致的问题，记录一下以备查阅。



### Simulation Failed

​	Forge Script在执行时一共有两层仿真，第一层允许使用cheatcode，字节码的运行时实现依赖的是foundry代理过的；而第二层就基本与真实的EVM环境一致。

​	第二层仿真时不会为cheatcode而报错，只是会不起作用，从而导致一些受影响于cheatcode修改的环境的代码错误。

​	比如我在Script脚本中写了`vm.wrap(xxx)`，但是在simulation时不会生效，也就导致了这一错误。

​	这一问题可以通过`--skip-simulation`来解决，不过解决这个没啥意义，broadcast上链之后也不允许你用这些修改环境的cheatcode。需要指定某一个blocknumber，或者需要使得timestamp在某一个区间内，建议的做法是把要执行的脚本找一个合约包装起来，然后再写一个Script或者用cast来触发。



### 0 bytes of code

​	这是forge script的经典问题，无法处理0 bytes的contract。比方说我用CREATE/CREATE2去执行了一段initialize code，但是不返回任何runtime code，forge script 大概率就会报这个错。以及调用`Selfdestruct`（CTF中比较常见）时会造成合约的代码为0，forge script在这种时候就不会起作用。

​	我个人比较喜欢用 CREATE/CREATE2 来实现一些任务，以及其他一些情况不得不需要这么处理的话也得避免这一任务在simulation中出现，类似上一个问题的解法。

​	网上很多建议会说试试`--skip-simulation`，这是无效的，因为这只会跳过第二次的仿真，而 Script 会在第一次报错。~~尚且不知道第二次仿真能否处理因为无法到达这一步~~



### vm.startBroadcast

​	刚开始用foundry forge的时候对`vm.startBroadcast()`印象最深，以为是用intialize 封装了整个broadcast的脚本内容，*然而实际上并没有*。

​	`vm.startBroadcast()`会把交易的发出者更改为命令行传入的`--private-key`参数对应的地址。也可以通过加参数来改为其他。所以如果想要重入的话一般不要把重入函数写在Script的fallback/recevive里，还是得另外再开一个辅助合约。

​	还有一点难以意识到的是即使你指定了`--broadcast`，也只会广播`vm.startBroadcast`和`vm.stopBroadcast`包裹的内容。同理你要是不指定`is Script`或`vm.startBroadcast`，大概率也不会广播。还有就是Script 的每一次external call都是隔离的交易，由于网络因素交易之间可能时间差距会很大，也没有办法保证后面的就正确执行/不会被抢先。



### Unknown contract at address 0xbebe...

​	这是指定`--debug`调试时可能会出现的问题，forge 不会把你的源代码映射到这一地址上。好像有 feature request 有提到这一点，不知道现在实现了没有。~~如果有的话可以告诉我一声~~

​	调试方案我目前一般还是使用 electron.js 构建的 remix desktop（remix online连anvil啥的容易触发CORS），较短的、没啥环境依赖的代码可以丢到[EVM.code playground](https://www.evm.codes/playground) 。forge这个终端调试实在不方便看栈上数据、内存数据等。



### Others

​	Foundry 最好用的应该还是用来test和fuzz啥的，以及很多的 cheatcode 和 console。[文档](https://book.getfoundry.sh/)

​	其他的目前想不起来。以后遇到了或者想起来了在写吧。有问题欢迎找我...