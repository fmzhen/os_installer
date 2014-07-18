#!/bin/bash
#add the compute nova

##########################config  compute  service#################
IP=$(/sbin/ifconfig eth0 | grep 'inet addr' | \
        sed 's/^.*addr://g' | sed 's/  Bcast.*$//g')
CONTROLLERIP=$2
HOSTNAME=$1
hostname $HOSTNAME
echo $HOSTNAME > /etc/hostname
sed -i "1a $CONTROLLERIP controller" /etc/hosts

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
sed -i '$a [database] \
    connection = mysql://nova:NOVA_DBPASS@controller/nova' /etc/nova/nova.conf
sed -i '1a rpc_backend = rabbit \
    rabbit_host = controller \
    rabbit_password = RABBIT_PASS'  /etc/nova/nova.conf
sed -i '1a auth_strategy = keystone' /etc/nova/nova.conf
sed -i '$a [keystone_authtoken]\
    auth_uri = http://controller:5000\
    auth_host = controller\
    auth_port = 35357\
    auth_protocol = http\
    admin_tenant_name = service\
    admin_user = nova\
    admin_password = NOVA_PASS' /etc/nova/nova.conf
sed -i '1a glance_host = controller' /etc/nova/nova.conf
sed -i "1a my_ip = $IP" /etc/nova/nova.conf
sed -i "1a vncserver_listen = 0.0.0.0" /etc/nova/nova.conf
sed -i "1a vncserver_proxyclient_address = $IP" /etc/nova/nova.conf
sed -i "1a vnc_enabled = True" /etc/nova/nova.conf
sed -i "1a novncproxy_base_url = http://$CONTROLLERIP:6080/vnc_auto.html" /etc/nova/nova.conf

rm /var/lib/nova/nova.sqlite
service nova-compute restart

############################config network  service ###################
apt-get -y install nova-network nova-api-metadata
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
service nova-api-metadata restart
