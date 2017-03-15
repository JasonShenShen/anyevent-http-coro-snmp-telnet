#利用forkmanager和anyevent-server实现类似nginx的surpervisor和worker模式

nginx启动后，会根据worker配置数量fork对应进程数，同时启动父进程作为surpervisor，当worker进程数减少时会自动补充对应worker，我们的目标是利用forkmanager实现该功能，提供给httpserver使用。

##思路
* 利用forkmanager的on_start和on_finish事件，记录进入和退出的子进程；
* 利用forkmanager的start和finish控制总开启数量；
* 父进程注册TERM、INT、KILL信号，当退出进程号和父进程相同，发送term信号给各个子进程终止
* 子进程使用ae signal模块监听TERM、INT、KILL三种信号关闭ev循环并退出

##实现
* 启动5个线程worker，curl测试服务正常
```
-bash-4.1# nohup perl anyevent-http-server.pl -t 5 &
[1] 3999
-bash-4.1# nohup: 忽略输入并把输出追加到"nohup.out"
-bash-4.1# ps -ef|grep anyevent-http-server.pl
root      3999 27832  5 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4000  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4001  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4002  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4003  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4004  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4008 27832  0 15:24 pts/3    00:00:00 grep anyevent-http-server.pl
```
* 关闭worker 4000，自动启动新的worker 4017，服务没有任何影响
```
-bash-4.1# kill 4000
-bash-4.1# ps -ef|grep anyevent-http-server.pl
root      3999 27832  1 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4001  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4002  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4003  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4004  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4017  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4021 27832  0 15:24 pts/3    00:00:00 grep anyevent-http-server.pl
```
* 关闭父进程，所有进程关闭
```
-bash-4.1# kill 3999
-bash-4.1# ps -ef|grep anyevent-http-server.pl
root      4036 27832  0 15:24 pts/3    00:00:00 grep anyevent-http-server.pl
[1]+  Done                    nohup perl anyevent-http-server.pl -t 5
```

##benchmark

###并发100 5000连接
* 1 worker模式
Requests per second:    682.94 [#/sec] (mean)
* 5 worker模式
Requests per second:    4486.96 [#/sec] (mean)

###并发1  5000连接
* 1 worker模式
Requests per second:    854.15 [#/sec] (mean)
* 5 worker模式
Requests per second:    876.04 [#/sec] (mean)

###打开keepalive 并发100 5000连接
Requests per second:    5357.12 [#/sec] (mean)

#接收http请求后，利用coro-telnet和coro-snmp实现协程建立和设备交互session完成请求指标并返回

* 通过协程组进行设备交互，使用async_pool监听完成状态，通过anyevent::timer异步实现状态和log的response。
* 附上http请求和telnet服务结果，发送一次http请求，请50台设备做show users只要6秒钟就可以返回
```
-bash-4.3$ time curl http://127.0.0.10:19999?pretty -d '{
>     "hostip": "1.1.1.1,2.2.2.2,3.3.3.3",
>     "items": "show users"
> }'
...
...
real    0m6.008s
user    0m0.002s
sys     0m0.003s
bash-4.1$ curl http://127.0.0.1:19999?pretty -d '{
    "hostip": "192.168.6.87,192.168.6.87,192.168.6.87",
    "items": "show users"
}'
show users
    Line       User       Host(s)              Idle       Location
* 66 vty 0     aaa        idle                 00:00:00 192.168.6.150
  67 vty 1     aaa        idle                 00:00:03 192.168.6.150
  Interface    User               Mode         Idle     Peer Address
BJ-BJ-ZU-V-2.test
##################################0##################################
show users
    Line       User       Host(s)              Idle       Location
  66 vty 0     aaa        idle                 00:00:00 192.168.6.150
* 67 vty 1     aaa        idle                 00:00:03 192.168.6.150
  Interface    User               Mode         Idle     Peer Address
BJ-BJ-ZU-V-2.test
##################################1##################################
show users
    Line       User       Host(s)              Idle       Location
  66 vty 0     aaa        idle                 00:00:00 192.168.6.150
  67 vty 1     aaa        idle                 00:00:00 192.168.6.150
* 69 vty 3     aaa        idle                 00:00:00 192.168.6.150
  Interface    User               Mode         Idle     Peer Address
BJ-BJ-ZU-V-2.test
##################################2##################################
You have mail in /var/spool/mail/slview
bash-4.1$ 
bash-4.1$ time curl http://192.168.6.150:18888?pretty -d '{
>     "hostip": "192.168.6.87,192.168.6.87,192.168.6.87",
>     "items": "ifhcinoctets"
> }'
"192.168.6.87_1_ifhcinoctets": "12010862272"
"192.168.6.87_4_ifhcinoctets": "0"
"192.168.6.87_5_ifhcinoctets": "0"
...
...
##################################2##################################
real    0m3.014s
user    0m0.007s
sys     0m0.004s
```
