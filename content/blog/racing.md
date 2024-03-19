---
title: "Racing and Smashing the state machine. learn from bh23"
date: 2023-08-17T00:00:00+08:00
---

# Thesis content & Personal summary

整理总结自`jameskettle`在`Black Hat USA 2023`上的发布的演讲主题和文章`Smashing the state machine: the true potential of web race conditions`[^1]，并夹杂个人琐碎的理解和联想。





## Limited exploit

大多数网站使用**多线程**处理并发请求，所有的读写都来自一个**单一的、共享**的数据库。应用程序代码很少考虑到**并发风险**，因此，竞态冒险问题困扰着大量的web应用。竞争问题在此之前集中在极少数的场景中，由于**测试困难、缺乏工具、网络抖动、不可避免的延迟**等因素，这一利用并没有广泛流行、其威胁性没有完整体现。

![race-conditions-discount-code-race](Racing and Smashing the state machine/race-conditions-discount-code-race.png)

经典的竞争冒险利用包括**多次应用同一折扣**、**重复提取或转移账户余额的现金**等，基本可以归纳为**Limit-overrun attack**，利用应用存在的的**检查时间，使用时间(time of check, time of use, TOCTOU)**的缺陷，绕过安全保护多次执行受保护操作。



## Parallel transmission Technique

单包攻击解决了网络抖动，使得每一次攻击都像是在本地系统上进行的，这暴露了以前几乎不可能检测或利用的漏洞。**单包攻击比末字节同步的效率仍然高出一个数量级，如果服务端支持HTTP /2应首先选用。**

### HTTP 2 - Single Package Attack Technique

对于`HTTP /2`竞争利用的稳定性，`jameskettle`采用 USENIX presentation Timeless Timing Attacks[^2] 的方式，利用`HTTP /2`**多路复用特性**，在单个连接并发地发送 HTTP 请求，可以使得两个请求直接的间隔极小(<1ms)。这种思路与2020年的一个研究十分相似[^3]

![9c53-article-blackhat_diagrams-13](Racing and Smashing the state machine/9c53-article-blackhat_diagrams-13-16922686162413.png)



### HTTP 1.x - Last-byte sync

由于HTTP 1.x为每一个请求使用一次TCP连接，无法沿用HTTP2的方法。为了提高`HTTP /1.x`竞争利用的稳定性，`jameskettle`通过对 Nagle's algorithm[^4] 创造性滥用，提出了一种`末字节同步(last-byte sync technique)`的方式，并完成了具体的实现。

*选用一个已有的HTTP 2 library来hook

首先，预先发送每个请求的大部分内容: 

如果请求没有正文，则发送所有报头，但不设置 END_STREAM 标志。保留设置了 END_STREAM 的空数据帧。 如果请求有正文，发送 headers 和除了最后一个字节之外的所有正文数据。保留一个包含最后字节的数据段。

接下来，准备发送最后的帧: 

等待100ms以确保初始帧已经发送。确保TCP_NODELAY被禁用(Nagle's algorithm对最后的帧进行批处理是至关重要的)。发送一个ping包来暖化本地连接(如果你不这样做，OS网络栈会把第一个final-frame放在一个单独的数据包中)。

最后，发送被扣留的帧。

![d56c-article-blackhat_diagrams-14](Racing and Smashing the state machine/d56c-article-blackhat_diagrams-14-16922686162414.png)



## Black-Box detection

在竞争冒险利用里**复杂度(时间)**是一个关键的因素，他与`race window`状态的存在时间有较大的关联。有些时候较长时间的响应可能意味着后端处理可能应用到了另外的线程，在有些时候可以作为利用点。

然而值得注意的是，许多应用程序位于前端服务器后面，这些应用程序可能决定将一些请求通过现有连接转发到后端， 并为其他应用程序**创建新的连接**。 因此，不应该将不一致的请求时间归因于应用程序行为，例如只允许单个线程一次访问资源的锁定机制。**前端请求路由**通常是在每个连接的基础上进行的，因此可以通过执行服务器端连接**预热(在执行攻击之前发送一些无关紧要的请求)**来平滑请求时间。

xxxxxxxxxx $ cast call 0x364Ca1729564bdB0cE88301FC72cbE3dCCcC08eD "getFlag()" -r https://eth-sepolia.g.alchemy.com/v2/SMfUKiFXRNaIsjRSccFuYCq8Q3QJgks8 --private-key <64byteskey>  | cut -c3- | xxd -r -p | (cat && printf "\x0A") 8TCP1P{4_b1t_of_f0undry_s3nd_4nd_abiCoder_w0n7_hur7_y34h}bash



### Detailed Method

具体而言，相关测试需要**发送大量的请求**，以最大限度地增加可见副作用的机会，并减轻服务器端的抖动。

可以把这看作是一种**基于混沌的策略**——如果我们看到了一些**有趣(或是不常规)**的事情，我们需要在后面的测试中弄清楚实际发生了什么。 准备好你的混合请求，目标端点和参数，以触发所有相关的代码路径。在可能的情况下，使用多个请求多次触发每个代码路径，使用不同的输入值。

接下来，通过混合发送你的请求，在每个请求之间间隔几秒钟，对端点在正常情况下的行为进行基准测试。 最后，使用单包攻击(如果不支持 HTTP/2，则使用 **last-byte sync** )一次性发送所有请求。可以在`Turbo Intruder`中使用`single package attack template`，或者在`repeater`中使用平行发送选项。

分析结果并**以任何偏离基准行为**的方式寻找线索。这可能是一个或多个回复的变化，或者是二阶效应，比如不同的邮件内容，或者是会话中可见的变化。线索可能是微妙的，违反直觉的。

**几乎任何东西**都可以成为线索，但要密切注意请求处理时间。如果它比你预期的时间短，这可能表明数据正在被传递到一个单独的线程，大大增加了漏洞的机会。如果它比你预期的长，这可能表明资源限制或应用程序正在使用锁定来避免并发问题。

要注意的是，PHP 默认锁定 sessionid，因此您需要为批处理中的每个请求使用单独的会话，否则它们将被按照顺序处理。以及越少的同时请求意味着对事件更加敏感、需要更多的测试次数。



## White-Box Code Analyze

从白盒角度分析这竞争冒险漏洞无疑是困难且难以完备的，即使可以获取源代码也应该做大量的黑盒测试。

### CVE-2022-4037 Gitlab

这是作者在文中提到的唯一白盒示例，已经做了修复[^5]。

```bash
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
git clone https://gitlab.com/gitlab-org/gitlab.git
cd gitlab
git reset --hard 613dbd78
```

GitLab 的仓库较为庞大，如果你对其并不是很熟悉，👆这将是一个错误的决定。

```bash
cd ..; rm -rf gitlab/
```

GitLab 的认证部分集成了`Ruby on rails`认证框架**devise**[^9]。

[/lib/devise/models/confirmable.rb](https://github.com/heartcombo/devise/blob/ec0674523e7909579a5a008f16fb9fe0c3a71712/lib/devise/models/confirmable.rb)

![image-20230816231345119](Racing and Smashing the state machine/image-20230816231345119.png)

将传入的表单 email 内容解析，赋值给该实例的`unconfirm_email`。

![image-20230816225924835](Racing and Smashing the state machine/image-20230816225924835.png)

这里将`Devise.friendly_token`给出的 **unique token **赋给了实例变量`@raw_confirmation_token`，在之后进行了保存。

![image-20230816232622027](Racing and Smashing the state machine/image-20230816232622027.png)

将实例变量`@raw_confirmation_token`以及`opts`从数据库中加载到`send_devise_notification`函数中，发送邮件。由于`send_devise_notification`调用了另外的线程，因而在此过程中会造成`race window`。

![未命名绘图.drawio](Racing and Smashing the state machine/未命名绘图.drawio.png)

## Common exploitation categories

文中提到的三种竞争冒险利用方式，有一定的交叉部分，并且实际情况中可能不止这四种。

- Limit-overrun: 传统的 racing 方法，建立在TOCTOU的基础上，通过对某一限制的**竞争滥用**，实现受保护操作的重复执行。

- Single-endpoint collisions: 单请求的重复发送，难以白盒探测这一问题，而**后端复杂性**给予了这一类漏洞较大的影响。上文提到的CVE-2022-4037就属这一类。

- Multi-endpoint collisions: **多请求、多结束点**的利用。在复杂请求的过程中执行简单请求中插入简单请求，使得传递的未检验数据接触到受保护操作。具体可见下文的 Practice writeup。



## Defence

**避免混合不同时刻的数据**。案例中设计库从数据库中读取令牌，然后通过电子邮件将其发送到保存在实例变量中的地址。如果它从数据库中同时读取了令牌和电子邮件地址，或者将它们都传递到实例变量中，它就不会受到攻击。

通过使用 datastore 的并发特性，**确保敏感端点使状态更改原子化**。例如，使用单一数据库事务来检查付款是否匹配 cart 值并确认订单。作为深度防御措施，利用数据存储完整性/一致性特征，如唯一性约束。

**不要试图使用一个数据存储层来保护另一个**。例如，会话不适合防止对数据库的限制-超出攻击。

**确保你的会话处理框架保持会话内部一致**。单独更新会话变量而不是批量更新可能是一个不错的优化，但它是极其危险的。这也适用于 ORMs 通过隐藏像 transactions 这样的概念，他们为它们承担全部责任。

在某些架构中，完全避免服务器端状态可能是合适的，而是使用加密来推送状态客户端，如 JWT。




## Future Research

- Applied Range: 竞争的应用范围目前基本局限于Web应用，然而竞态冒险并不局限于特定的`web-app`架构。多线程单数据库应用程序是最容易推理的，但更复杂的设置通常会导致状态存储在更多的地方，而`ORMs`只是将危险隐藏在抽象层之下。像 NodeJS 这样的单线程系统暴露的稍微 少一些，但最终仍然可能容易受到攻击。

- Partial construction attacks: 部分构造攻击是数据结构在做出完整改变之前的状态未被限制访问，造成的中间态。下文会就相关的 pj0 的 WebRTC 研究做出简单总结。

- Single-packet attack enhancements: 单包攻击自身的优化，针对`延迟multi-endpoint单个数据包中特定请求的处理`，`总体支持的最大并行数量`、`从TCP转移到TLS层利用`三个层面。

- Unsafe data structures: 一、数据结构层在现实中应对竞争的方式——锁定。然而这一方式对于效率而言过于激进。因而有些时候锁定针对的是单个会话，这是如果使用两个单独的会话，该漏洞仍然是可利用的。二、批处理的结构使得开始处理一个请求时，它们会读取整个记录，将随后的读/写操作应用于该记录的本地内存副本，然后当请求处理完成时，整个记录被序列化回数据库。但如果两个请求同时对同一条记录进行操作，其中一个将最终从另一个重写数据库的更改。这意味着它们不能用来防御影响其他存储层的攻击。三、无保护是最常见的结构，并且是最容易利用的。

  paper中给出无保护下的可利用片段如下（应该事python）：

  ```python
  # Bypass code-based password reset
  session['reset_username'] = username
  session['reset_code'] = randomCode()
  Exploit: Simultaneous reset for $your-username and $victim-username
  ```

  ```python
  # Bypass 2FA
  session['user'] = username
  if 2fa_enabled:
      session['require2fa'] = true
  Exploit: Simultaneous login and sensitive page fetch
  ```

  ```python
  # Session-swap
  session['user'] = username
  set_auth_cookies_for(session['user'])
  Detect: Simultaneous login to two separate accounts from same session
  Exploit: Force anon session cookie on victim, then log in simultaneously
  ```



# Related Knowledge

文中提到的、以及与竞争密切相关的几个知识点。

## Atomic operation

如果这个操作所处的层(layer)的更高层不能发现其内部实现与结构，那么这个操作是一个**原子(atomic)操作**[^6]。原子操作可以是一个步骤，也可以是多个操作步骤，但是其顺序不可以被打乱，也不可以被切割而只执行其中的一部分。**将整个操作视作一个整体**是原子性的核心特征。

在多进程（线程）访问共享资源时，能够确保**所有其他的进程（线程）**都不在同一时间内访问相同的资源。原子操作（atomic operation）是不需要**synchronized**，不会被线程调度机制打断的操作；这种操作一旦开始，就一直运行到结束，中间不会有任何 context switch（上下文切换，指切换到另一个线程）[^7]。

**HTTP 请求**处理不是**原子**的——任何端点都可能通过不可见的子状态发送应用程序。这意味着在**竞争态势**下，一切都是多步骤的。



## Nagle's algorithm

约翰·纳格的文件描述了他所谓的“小数据包问题”－某个应用程序不断地提交小单位的资料，且某些常只占1 byte大小。而由于数据包具有40 bytes 的标头信息（TCP与IPv4各占20字节），这导致了41 bytes 大小的数据包只有 1 byte 的可用信息，造成庞大的浪费。这种状况常常发生于 Telnet 工作阶段－大部分的键盘操作会产生1字节的资料并马上提交。更糟的是，在慢速的网络连线下，这类的数据包会大量地在同一时点传输，造成壅塞碰撞。

纳格算法的工作方式是合并（coalescing）一定数量的输出资料后一次提交。特别的是，只要有已提交的数据包尚未确认，发送者会持续缓冲数据包，直到累积一定数量的资料才提交。

TCP 实现通常为应用程序提供一个接口来禁用 Nagle 算法。在Windows中，在注册表HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters 下新建一个名为 TcpAckFrequency 的 DWORD，使其值为0即可禁用 Nagle 算法。

在末字节同步攻击手段的结束帧发送就应用了内格尔算法对最后帧的批处理。



## Locking

### Optimistic Locking

乐观锁常见的有版本号和CAS算法两种机制[^8]。

- 版本号机制一般是在数据表中加上一个数据版本号version字段，表示数据被修改的次数，当数据被修改时，version值会加一。当线程A要更新数据值时，在读取数据的同时也会读取version值，在提交更新时，若刚才读取到的version值为当前数据库中的version值相等时才更新，否则重试更新操作，直到更新成功。~~_个人感觉相当于使用一个数据来保护另一个，并不能很好起到保护效果_~~

- 即**compare and swap（比较与交换）**，是一种有名的**无锁算法**。无锁编程，即不使用锁的情况下实现多线程之间的变量同步，也就是在没有线程被阻塞的情况下实现变量的同步，所以也叫非阻塞同步（Non-blocking Synchronization）。**CAS算法**涉及到三个操作数

  - 需要读写的内存值 V
  - 进行比较的值 A
  - 拟写入的新值 B

  当且仅当 V 的值等于 A时，CAS通过原子方式用新值B来更新V的值，否则不会执行任何操作（比较和替换是一个原子操作）。一般情况下是一个**自旋操作**，即**不断的重试**。



### Pessimistic Locking

总是假设最坏的情况，每次去拿数据的时候都认为别人会修改，所以每次在拿数据的时候都会上锁，这样别人想拿这个数据就会阻塞直到它拿到锁（**共享资源每次只给一个线程使用，其它线程阻塞，用完后再把资源转让给其它线程**）。传统的关系型数据库里边就用到了很多这种锁机制，比如行锁，表锁等，读锁，写锁等，都是在做操作之前先上锁。Java中`synchronized`和`ReentrantLock`等独占锁就是悲观锁思想的实现。

悲观锁是最激进的保护方式，会很大程度影响并发下的吞吐量。



# Metioned Practice Writeup

>paper中提到的web-security-lab。下面完成并记录了部分过程

## Lab: Limit overrun race conditions

https://portswigger.net/web-security/race-conditions/lab-race-conditions-limit-overrun

~~_先下个community burp 2023.9_~~

先买个最便宜的商品，简单测试下功能

![image-20230813210423059](Racing and Smashing the state machine/image-20230813210423059-16922686162425.png)

`GET /product`查看商品详细信息，`POST /card`将提交表单中的商品添加到 cart，`GET /cart`查看购物车，`POST /cart/coupon`应用优惠券，`POST /cart/checkout`完成购买动作然后303跳转到`GET /cart/order-comfirmation`显示购买后信息。

因为主题是`single-package-attack`，单包攻击，即一次发送多个请求。而该优惠券应用路由可能会造成可能存在的`Race Window`。

直接采用新版 burpsuite 提供的功能，将`POST /cart/coupon`发送到 repeater 19次，合并为一个组，然后调整发送方式，发送即可。（burp的send parallel对于http/1.1采用末字节同步技术，http/2采用单包攻击技术[^10]）

<img src="Racing and Smashing the state machine/image-20230813213040972-16922669383881.png" alt="image-20230813213040972" style="zoom:50%;" />

此时回到`GET /card`界面已经只有$19.25了，此时再购买即可。

<img src="Racing and Smashing the state machine/image-20230813213134092-16922669715043.png" alt="image-20230813213134092" style="zoom:33%;" />



## Lab: single-endpoint race conditions

https://portswigger.net/web-security/race-conditions/lab-race-conditions-single-endpoint

目标要把邮箱修改为`carlos@ginandjuice.shop`，而可以接触的只有`@exploit-0afe0072043930a78126f2df0155002a.exploit-server.net`下的邮箱。

使用 turbo Intruder 脚本单包攻击二十次

```python
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint,
                           concurrentConnections=1,
                           engine=Engine.BURP2
                           )

    for i in range(20):
        engine.queue(target.req, str(i), gate='race1')

    engine.openGate('race1')


def handleResponse(req, interesting):
    table.add(req)
```

回到邮箱界面可以明显注意到修改地址和`send to`地址基本不匹配



<img src="Racing and Smashing the state machine/image-20230817121032403.png" alt="image-20230817121032403" style="zoom: 50%;" />

现在仅保留两个报文副本，一个为可接收的邮箱，一个为`carlos@ginandjuice.shop`

多次发送（亲测把`carlos@ginandjuice.shop`放在后面成功率高。虽然同个TCP但可能还是有微秒级影响）

![image-20230817121740600](Racing and Smashing the state machine/image-20230817121740600.png)

验证地址再删除`carlos`用户就可以了。

## Lab: Multi-endpoint race conditions

https://portswigger.net/web-security/race-conditions/lab-race-conditions-multi-endpoint

网站整体功能和第一个实验差不多，但是少了coupon多了一个可购买的礼品卡，花$10得到的礼品卡就是一串code，使用后获得$10然后该code销毁失效。

`Multi-endpoint`是指多步请求的多个结束位置利用，通常是第一个请求比第二个请求更复杂（或触发速率限制），从而在第一个请求`endpoint`之前的`Race Window`完成第二个请求的`endpoint`。

在Repeater里，将`POST /card`和`POST /card/checkout`添加到一个新组中，然后通过单个连接按序列发送，对比响应时间。

然后再将`GET /`添加到该组开头，继续通过单个连接按序列发送，对比响应时间。

<img src="Racing and Smashing the state machine/image-20230813233044992-16922671326167.png" alt="image-20230813233044992" style="zoom:50%;" />

PortSwigger 的教程指出这里两次测试下的`POST /card`的响应时间要明显长于`POST /card/checkout`。可能是我的网络环境问题导致并不明显，或者需要更直观的数据体现。

添加目标修改`POST /card`的 productId 为1，通过 http/2 单包发送。这里可能由于一些干扰因素，需要多次尝试，提示`insufficient funds`就先移除jacket，换成一张card。

![image-20230813233159601](Racing and Smashing the state machine/image-20230813233159601-16922670750615.png)

_很明显是绕过的`/card/checkout`路由下的资金是否充裕检测直接结账 导致后续资金为负数_



## Lab: Partial construction race conditions

https://portswigger.net/web-security/race-conditions/lab-race-conditions-partial-construction

部分构造攻击[^11]是针对数据结构层面的利用，即在状态机改变过程中留下一个`race window`。例如 JSON 数据设定过程中留下了`undefined`或`null`的状态，PHP array 创建过程中留下了空数组。由于自定义客户端的处理不一，可能会对该中间状态做出不同的解释。

题目目标是利用不存在的邮箱注册账号，并赋有`/email`的邮箱客户端。提交注册请求，查看浏览器 DevTools > Network 可以看到资源`/resources/static/users.js`被加载，并泄露确认链接形似`/comfirm?token=`。

考虑服务端在保存token时存在部分构造状态。通过修改token进行测试：提交`/confirm?token=1`返回 "Incorrect token: 1"；提交`/confirm?token[]=`返回 "Incorrect token: Array"，由此可以确认服务端框架解析`token[]=`为空数组。现使用空数组匹配部分构造状态。（这里的单包初步测试出现了协议不一致的问题，直接修改再反复点击刷新为http/2）

为了避免错过短暂的`race window`，使用`turbo Intruder(Extension)`并发大量请求。

```python
def queueRequests(target, wordlists):

    engine = RequestEngine(endpoint=target.endpoint,
                                concurrentConnections=1,
                                engine=Engine.BURP2
                                )

    confirmationReq = '''POST /confirm?token[]= HTTP/2
Host: 0aae00b1046ded96810f3f720043001b.web-security-academy.net
Cookie: phpsessionid=iDVi7uegZUoLuFLuHslvxFHWwi0buIxL
Content-Length: 0

'''
    for attempt in range(20):
        currentAttempt = str(attempt)
        username = 'U0er' + currentAttempt

        # queue a single registration request
        engine.queue(target.req, username, gate=currentAttempt)

        # queue 50 confirmation requests - note that this will probably sent in two separate packets
        for i in range(50):
            engine.queue(confirmationReq, gate=currentAttempt)

        # send all the queued requests for this attempt
        engine.openGate(currentAttempt)


def handleResponse(req, interesting):
    table.add(req)
```

找到`/confirm`返回的200响应，登录。然后删除carlos用户即可完成。

![image-20230814214830252](Racing and Smashing the state machine/image-20230814214830252-16922686162426.png)

_u1s1 partial construction 实际上也是multi-endpoint的一种_



# WebRTC Research

https://googleprojectzero.blogspot.com/2021/01/the-state-of-state-machines.html

# Quote Link

[^1]: https://portswigger.net/research/smashing-the-state-machine

[^2]: https://www.usenix.org/conference/usenixsecurity20/presentation/van-goethem

[^3]: https://aaltodoc.aalto.fi/bitstream/handle/123456789/47110/master_Papli_Kaspar_2020.pdf

[^4]: https://en.wikipedia.org/wiki/Nagle%27s_algorithm

[^5]: https://gitlab.com/gitlab-org/gitlab/-/commit/e4d8d4f818275d42469d154b72fc6367b2b86bbb

[^6]: https://baike.baidu.com/item/%E5%8E%9F%E5%AD%90%E6%93%8D%E4%BD%9C/1880992

[^7]: https://www.zhihu.com/question/25532384/answer/81152571

[^8]: https://zhuanlan.zhihu.com/p/40211594

[^9]: https://github.com/heartcombo/devise

[^10]: https://portswigger.net/burp/documentation/desktop/tools/repeater/send-group#sending-requests-in-parallel

[^11]: https://portswigger.net/research/smashing-the-state-machine#partial-construction
