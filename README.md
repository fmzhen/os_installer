os_installer
============

##单节点安装OpenStack(Icehouse)

- 环境要求： 纯净的ubuntu12.04或14.04系统，单机单网卡。
- 安装的组件： 运行OpenStack所需要的最基本的组件：keystone/glance/nova/horizon。
- 网络： 网络使用的较老的nova-network。网络模式使用flatdhcp,若想安装时创建网络，将网络作为参数传入即可,如 `source ./All_in_one.sh 192.168.0.1/24`。也可安装完成后，自己创建
`nova network-create demo-net --bridge br100 --multi-host T --fixed-range-v4 $1`

- 安装  直接用root执行All_in_one.sh。  如： `source ./All_in_one.sh 192.168.0.1/24` 或 `source  ./All_in_one.sh`


###配置主机信息
配置主机名为controller,并在hosts中将controller和eth0的ip对应起来。

###安装数据库
安装mysql数据库, mysql绑定在eth0的ip上。安装过程中会让你设置mysql密码，请
设置为“admin”。然后会出现mysql安装安装的选项，根据需求答yes/no（不清楚的就选yes）。

###配置软件源和消息中间件
添加Icehouse的ubuntu源和安装rabbitmq。

###安装keystone服务

- 创建了admin用户（密码： ADMIN_PASS）。并关联到了名为admin租户上，角色为admin。
- 创建了demo用户（密码： DEMO_PASS）。并关联到了名为demo的租户上，角色为普通用户。
- 在root家目录下新建了一个adminrc文件，里面保存了admin的认证信息。在shell下使用OpenStack命令前，先source  adminrc导入环境变量。
0 ++ / 249 --
###安装glance服务
- 配置glance-api.conf时，在开始部分添加了rabbit_host和rabbit_password两项，但是原配置文件里有rabbit的配置，这里只是在原有配置前面加上了新配置，安装完成后正常使用也是没有问题的。但是若按照官网安装完ceilometer后，这个原配置信息会干扰glance，导致glance出错。
- glance api注册的是v2（v2用来部署CF会有问题）。

为防止网络不好，影响安装进程，将cirros镜像下载部分注释掉了。当OpenStack安装完成后，可通过下面命令手动下载：
```
wget http://cdn.download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
glance image-create --name "cirros-0.3.2-x86_64" --disk-format qcow2 \
   --container-format bare --is-public True --progress < cirros-0.3.2-x86_64-disk.img
```
可根据情况将注释去掉
###安装compute-controller相关服务
这里安装除nova-compute和nova-network之外的其他nova服务




###安装compute服务
安装nova-compute服务，由于我们只有一台机器，所以即是控制节点，也是计算节点。虚拟化使用的是kvm。

###安装nova-network服务
官网上这步安装的服务是nova-network 和nova-api-metadata(在nova-network的multi-host情况下有用)。由于nova-api和nova-api-metadata不兼容，所以没有安装nova-api-metadata。
- 创建了default安全组，开放22（tcp）和-1(icmp)端口。



###安装dashboard
安装完成后，在浏览器中输入 http://本机ip/horizon  即可看到horizon界面，输入admin / ADMIN_PASS即可登陆进去。











