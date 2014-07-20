shell tip
==
这些安装脚本没什么逻辑，就是按照官网上的安装教程用一堆命令堆砌而成的。shell的一些命令用起来确实不好用，主要是太容易忘。下面是使用过程中遇到的一些问题。

1. 获取IP地址：获取ip地址：`/sbin/ifconfig eth0 | grep 'inet addr' | sed 's/^.*addr://g' | sed 's/Bcast.*$//g' ` (这个IP地址不纯粹，后面跟两个空格。可以在Bcast前面加两个空格解决。)
2. 使用sed想文本中插入一行时，操作命令单引号和双引号都可以，但是若里面有变量，则使用双引号，里面的变量不需任何处理便会自动显示出来，而单引号则不行(无论是$A还是${A}都不行)。`sed -i "1a $IP controller" /etc/hosts`
3. 使用grep搜索“[mysqld]”时,由于[]是和正则表达式相关的，所以用转义字符\。
4. 取变量${}方式的应用：用在变量后面紧跟内容的时候。如`sed -i "${num}a auth_port = 35357" /etc/glance/glance-api.conf`
5. sed命令如果用双引号的话，那个插入多行的效果就不行。但是单引号的话，变量又识别不了。只有一条一条添加。单引号的多行行和行之间要加\和回车。
6. sed插入多行时，最后一行一定不要在结尾加 \，不然会出错的。添加的每行后面都有一个\了。
7. shell操纵mysql数据库的方法一：`mysql -hhostname -Pport -uusername -ppassword -e “sql语句” `
8. 实际操作数据库的方法：

 

```
mysql -uroot -padmin << EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
IDENTIFIED BY 'NOVA_DBPASS';
EOF
```