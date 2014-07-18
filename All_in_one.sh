#!/bin/bash
#####
#set -e
#config the hostname 
IP=$(/sbin/ifconfig eth0 | grep 'inet addr' | \
    sed 's/^.*addr://g' | sed 's/  Bcast.*$//g')
hostname controller
echo "controller" > /etc/hostname
sed -i "1a $IP controller" /etc/hosts

#install and config mysql,the password please set "admin".
apt-get -y install python-mysqldb mysql-server
sed -i "s/127.0.0.1/$IP/g" /etc/mysql/my.cnf   #replace the first find string
num=$(grep -n "\[mysqld\]" /etc/mysql/my.cnf | cut -d ":" -f 1)
sed -i "${num}a default-storage-engine = innodb" /etc/mysql/my.cnf
sed -i "${num}a collation-server = utf8_general_ci" /etc/mysql/my.cnf
sed -i "${num}a init-connect = 'SET NAMES utf8'" /etc/mysql/my.cnf
sed -i "${num}a character-set-server = utf8" /etc/mysql/my.cnf
service mysql restart
mysql_secure_installation

#OpenStack packages
apt-get -y install python-software-properties
add-apt-repository -y cloud-archive:icehouse
apt-get update

#install messaging server
apt-get -y install rabbitmq-server
rabbitmqctl change_password guest RABBIT_PASS

####################KEYSTONE##############################
#install and config keystone 
apt-get -y install keystone
sed -i 's/connection = sqlite:\/\/\/\/var\/lib\/keystone\/keystone.db/ \
connection = mysql:\/\/keystone:KEYSTONE_DBPASS@controller\/keystone/g' /etc/keystone/keystone.conf
rm /var/lib/keystone/keystone.db
mysql -u root -padmin << EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
IDENTIFIED BY 'KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
IDENTIFIED BY 'KEYSTONE_DBPASS';
EOF
su -s /bin/sh -c "keystone-manage db_sync" keystone
sed -i "1a admin_token = ADMIN" /etc/keystone/keystone.conf
sed -i "1a log_dir = /var/log/keystone" /etc/keystone/keystone.conf
#restart the keystone.As the keystone just start,the after action will not response.so should sleep several seconds.
service keystone restart
export OS_SERVICE_TOKEN=ADMIN
export OS_SERVICE_ENDPOINT=http://controller:35357/v2.0
sleep 5
# create an administrative user
keystone user-create --name=admin --pass=ADMIN_PASS --email=ADMIN_EMAIL
keystone role-create --name=admin
keystone tenant-create --name=admin --description="Admin Tenant"
keystone user-role-add --user=admin --tenant=admin --role=admin
keystone user-role-add --user=admin --role=_member_ --tenant=admin
# create an normal user demo
keystone user-create --name=demo --pass=DEMO_PASS --email=DEMO_EMAIL
keystone tenant-create --name=demo --description="Demo Tenant"
keystone user-role-add --user=demo --role=_member_ --tenant=demo
#create the service tenant
keystone tenant-create --name=service --description="Service Tenant"
#define the keystone service and API endpoints
keystone service-create --name=keystone --type=identity \
  --description="OpenStack Identity"
keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ identity / {print $2}') \
  --publicurl=http://controller:5000/v2.0 \
  --internalurl=http://controller:5000/v2.0 \
  --adminurl=http://controller:35357/v2.0
cat > ~/adminrc << EOF
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://controller:35357/v2.0
EOF
source ~/adminrc
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT


#########################GLANCE###################################################
#install keystone 
apt-get -y install glance python-glanceclient
sed -i 's/sqlite_db = \/var\/lib\/glance\/glance.sqlite/ \
connection = mysql:\/\/glance:GLANCE_DBPASS@controller\/glance/g'\
 /etc/glance/glance-api.conf  /etc/glance/glance-registry.conf
sed -i '1a rpc_backend = rabbit\
rabbit_host = controller\
rabbit_password = RABBIT_PASS' \
/etc/glance/glance-api.conf
rm /var/lib/glance/glance.sqlite
mysql -uroot -padmin << EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
IDENTIFIED BY 'GLANCE_DBPASS';
EOF
su -s /bin/sh -c "glance-manage db_sync" glance
keystone user-create --name=glance --pass=GLANCE_PASS \
   --email=glance@example.com
keystone user-role-add --user=glance --tenant=service --role=admin

#edit the glance's configuration
num=$(grep -n "\[keystone_authtoken\]" /etc/glance/glance-api.conf | cut -d ":" -f 1)
sed -i "$(($num+1)),$(($num+6))d" /etc/glance/glance-api.conf
sed -i "${num}a auth_uri = http://controller:5000" /etc/glance/glance-api.conf
sed -i "${num}a auth_host = controller" /etc/glance/glance-api.conf
sed -i "${num}a auth_port = 35357" /etc/glance/glance-api.conf
sed -i "${num}a auth_protocol = http" /etc/glance/glance-api.conf
sed -i "${num}a admin_tenant_name = service" /etc/glance/glance-api.conf
sed -i "${num}a admin_user = glance" /etc/glance/glance-api.conf
sed -i "${num}a admin_password = GLANCE_PASS" /etc/glance/glance-api.conf
num=$(grep -n "\[keystone_authtoken\]" /etc/glance/glance-registry.conf | cut -d ":" -f 1)
sed -i "$(($num+1)),$(($num+6))d" /etc/glance/glance-registry.conf
sed -i "${num}a auth_uri = http://controller:5000" /etc/glance/glance-registry.conf
sed -i "${num}a auth_host = controller" /etc/glance/glance-registry.conf
sed -i "${num}a auth_port = 35357" /etc/glance/glance-registry.conf
sed -i "${num}a auth_protocol = http" /etc/glance/glance-registry.conf
sed -i "${num}a admin_tenant_name = service" /etc/glance/glance-registry.conf
sed -i "${num}a admin_user = glance" /etc/glance/glance-registry.conf
sed -i "${num}a admin_password = GLANCE_PASS" /etc/glance/glance-registry.conf
num=$(grep -n "\[paste_deploy\]" /etc/glance/glance-api.conf | cut -d ":" -f 1)
sed -i "${num}a flavor = keystone" /etc/glance/glance-api.conf
num=$(grep -n "\[paste_deploy\]" /etc/glance/glance-registry.conf | cut -d ":" -f 1)
sed -i "${num}a flavor = keystone" /etc/glance/glance-registry.conf
#create the glance's ednpoint
keystone service-create --name=glance --type=image \
  --description="OpenStack Image Service"
keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ image / {print $2}') \
  --publicurl=http://controller:9292 \
  --internalurl=http://controller:9292 \
  --adminurl=http://controller:9292
service glance-registry restart
service glance-api restart
sleep 1
mkdir ~/images
cd ~/images/
#wget http://cdn.download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
#glance image-create --name "cirros-0.3.2-x86_64" --disk-format qcow2 \
#  --container-format bare --is-public True --progress < cirros-0.3.2-x86_64-disk.img


#########################COMPUTE-CONTROLLER###################################
apt-get -y install nova-api nova-cert nova-conductor nova-consoleauth \
  nova-novncproxy nova-scheduler python-novaclient
sed -i '$a [database] \
connection = mysql://nova:NOVA_DBPASS@controller/nova' /etc/nova/nova.conf
sed -i '1a rpc_backend = rabbit \
rabbit_host = controller \
rabbit_password = RABBIT_PASS'  /etc/nova/nova.conf
sed -i "1a my_ip = $IP" /etc/nova/nova.conf
sed -i "1a vncserver_listen = 0.0.0.0" /etc/nova/nova.conf
sed -i "1a vncserver_proxyclient_address = $IP" /etc/nova/nova.conf
rm /var/lib/nova/nova.sqlite
mysql -uroot -padmin << EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
IDENTIFIED BY 'NOVA_DBPASS';
EOF
su -s /bin/sh -c "nova-manage db sync" nova
keystone user-create --name=nova --pass=NOVA_PASS --email=nova@example.com
keystone user-role-add --user=nova --tenant=service --role=admin
sed -i '1a auth_strategy = keystone' /etc/nova/nova.conf
sed -i '$a [keystone_authtoken]\
auth_uri = http://controller:5000\
auth_host = controller\
auth_port = 35357\
auth_protocol = http\
admin_tenant_name = service\
admin_user = nova\
admin_password = NOVA_PASS' /etc/nova/nova.conf
keystone service-create --name=nova --type=compute \
  --description="OpenStack Compute"
keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ compute / {print $2}') \
  --publicurl=http://controller:8774/v2/%\(tenant_id\)s \
  --internalurl=http://controller:8774/v2/%\(tenant_id\)s \
  --adminurl=http://controller:8774/v2/%\(tenant_id\)s
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

############################COMPUTE###########################
apt-get -y install nova-compute-kvm python-guestfs
dpkg-statoverride  --update --add root root 0644 /boot/vmlinuz-$(uname -r)
cat > /etc/kernel/postinst.d/statoverride << EOF
#!/bin/sh
version="$1"
# passing the kernel version is required
[ -z "${version}" ] && exit 0
dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-${version}
EOF
chmod +x /etc/kernel/postinst.d/statoverride
sed -i '1a glance_host = controller' /etc/nova/nova.conf
sed -i "1a vnc_enabled = True" /etc/nova/nova.conf
sed -i "1a novncproxy_base_url = http://${IP}:6080/vnc_auto.html" /etc/nova/nova.conf

service nova-compute restart

#######################NOVA-NETWORK##########################
sed -i '1a network_api_class = nova.network.api.API\
security_group_api = nova' /etc/nova/nova.conf
service nova-api restart
service nova-scheduler restart
service nova-conductor restart

apt-get -y install nova-network
sed -i '1a network_api_class = nova.network.api.API \
security_group_api = nova \
firewall_driver = nova.virt.libvirt.firewall.IptablesFirewallDriver \
network_manager = nova.network.manager.FlatDHCPManager \
network_size = 254 \
allow_same_net_traffic = False \
multi_host = True \
send_arp_for_ha = True \
share_dhcp_address = True \
force_dhcp_release = True \
flat_network_bridge = br100 \
flat_interface = eth0 \
public_interface = eth0 ' /etc/nova/nova.conf
service nova-network restart
sleep 3
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
if [ "$1" == "" ]; then
    :
else
    nova network-create demo-net --bridge br100 --multi-host T --fixed-range-v4 $1
fi 

#############################DASHBOARD##########################
apt-get -y install apache2 memcached libapache2-mod-wsgi openstack-dashboard
apt-get -y remove --purge openstack-dashboard-ubuntu-theme

