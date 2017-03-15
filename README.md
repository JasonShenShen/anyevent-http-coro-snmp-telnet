#����forkmanager��anyevent-serverʵ������nginx��surpervisor��workerģʽ
nginx�����󣬻����worker��������fork��Ӧ��������ͬʱ������������Ϊsurpervisor����worker����������ʱ���Զ������Ӧworker�����ǵ�Ŀ��������forkmanagerʵ�ָù��ܣ��ṩ��httpserverʹ�á�

##˼·
* ����forkmanager��on_start��on_finish�¼�����¼������˳����ӽ��̣�
* ����forkmanager��start��finish�����ܿ���������
* ������ע��TERM��INT��KILL�źţ����˳����̺ź͸�������ͬ������term�źŸ������ӽ�����ֹ
* �ӽ���ʹ��ae signalģ�����TERM��INT��KILL�����źŹر�evѭ�����˳�

##ʵ��
* ����5���߳�worker��curl���Է�������
```
-bash-4.1# nohup perl anyevent-http-server.pl -t 5 &
[1] 3999
-bash-4.1# nohup: �������벢�����׷�ӵ�"nohup.out"
-bash-4.1# ps -ef|grep anyevent-http-server.pl
root      3999 27832  5 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4000  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4001  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4002  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4003  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4004  3999  0 15:24 pts/3    00:00:00 perl anyevent-http-server.pl -t 5
root      4008 27832  0 15:24 pts/3    00:00:00 grep anyevent-http-server.pl
```

* �ر�worker 4000���Զ������µ�worker 4017������û���κ�Ӱ��
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

* �رո����̣����н��̹ر�
```
-bash-4.1# kill 3999
-bash-4.1# ps -ef|grep anyevent-http-server.pl
root      4036 27832  0 15:24 pts/3    00:00:00 grep anyevent-http-server.pl
[1]+  Done                    nohup perl anyevent-http-server.pl -t 5
```

##benchmark
###����100 5000����
* 1 workerģʽ
Requests per second:    682.94 [#/sec] (mean)
* 5 workerģʽ
Requests per second:    4486.96 [#/sec] (mean)

###����1  5000����
* 1 workerģʽ
Requests per second:    854.15 [#/sec] (mean)
* 5 workerģʽ
Requests per second:    876.04 [#/sec] (mean)

###��keepalive ����100 5000����
Requests per second:    5357.12 [#/sec] (mean)

##TODO
receive http req to use coro get snmp��telnet��ssh session

#����http���������coro-telnet��coro-snmpʵ��Э�̽������豸����session�������ָ�겢����
ͨ��Э��������豸������ʹ��async_pool�������״̬��ͨ��anyevent::timer�첽ʵ��״̬��log��response��
����http�����telnet������������һ��http������50̨�豸��show usersֻҪ6���ӾͿ��Է���
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
