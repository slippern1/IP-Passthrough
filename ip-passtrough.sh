#!/bin/sh

#Bring up interfaces
/usr/sbin/ifconfig wwan0 up
/usr/sbin/ifconfig eth0 up
#Get IPv4-address from modem
IPV4_ADDRESS=$(mmcli --modem=0 --bearer=0 | grep address: | awk '{print $3}')
echo "IPv4-Address: " $IPV4_ADDRESS
#Get IPv4-gateway from modem
IPV4_GATEWAY=$(mmcli --modem=0 --bearer=0 | grep gateway: | awk '{print $3}')
echo "IPv4-Gateway: " $IPV4_GATEWAY
#Get IPv4-subnet-prefix from modem
IPV4_SUBNET_PREFIX=$(mmcli --modem=0 --bearer=0 | grep prefix: | awk '{print $3}')
echo "IPv4-Subnet: " $IPV4_SUBNET_PREFIX
#Get IPv4-DNS servers from modem
IPV4_DNS_SERVER1=$(mmcli --modem=0 --bearer=0 | grep dns: | awk '{print $3}')
IPV4_DNS_SERVER2=$(mmcli --modem=0 --bearer=0 | grep dns: | awk '{print $4}')

#Remove "," from DNS-servers.
IPV4_DNS_SERVER1=${IPV4_DNS_SERVER1%,*}
IPV4_DNS_SERVER2=${IPV4_DNS_SERVER2%,*}
echo "DNS-Server 1: " $IPV4_DNS_SERVER1
echo "DNS-Server 2: " $IPV4_DNS_SERVER2


#Calculate IP-settings for DHCP-server
#IPV4_DHCP_NETWORK=$(ipcalc -b $IPV4_ADDRESS/29 | grep Network: | awk '{print $2}')
#IPV4_DHCP_NETMASK=$(ipcalc -b $IPV4_ADDRESS/29 | grep Netmask: | awk '{print $2}')
#IPV4_DHCP_HOSTMIN=$(ipcalc -b $IPV4_ADDRESS/29 | grep HostMin: | awk '{print $2}')
#IPV4_DHCP_HOSTMAX=$(ipcalc -b $IPV4_ADDRESS/29 | grep HostMax: | awk '{print $2}')
#IPV4_DHCP_BROADCAST=$(ipcalc -b $IPV4_ADDRESS/29 | grep Broadcast: | awk '{print $2}')

#Calculate IP-Settings for mirroring Telenor DHCP subnet
IPV4_DHCP_NETWORK=$(ipcalc -b $IPV4_ADDRESS/$IPV4_SUBNET_PREFIX | grep Network: | awk '{print $2}')
IPV4_DHCP_NETMASK=$(ipcalc -b $IPV4_ADDRESS/$IPV4_SUBNET_PREFIX | grep Netmask: | awk '{print $2}')
IPV4_DHCP_HOSTMIN=$(ipcalc -b $IPV4_ADDRESS/$IPV4_SUBNET_PREFIX | grep HostMin: | awk '{print $2}')
IPV4_DHCP_HOSTMAX=$(ipcalc -b $IPV4_ADDRESS/$IPV4_SUBNET_PREFIX | grep HostMax: | awk '{print $2}')
IPV4_DHCP_BROADCAST=$(ipcalc -b $IPV4_ADDRESS/$IPV4_SUBNET_PREFIX | grep Broadcast: | awk '{print $2}')

#Removing subnet-prefix from NETWORK.
IPV4_DHCP_NETWORK_WITHOUT_SUBNET_PREFIX=${IPV4_DHCP_NETWORK%/*}
echo "IPv4-DHCP-Network: " $IPV4_DHCP_NETWORK
echo "IPv4-DHCP-Netmask: " $IPV4_DHCP_NETMASK
echo "IPv4-DHCP-HostMin: " $IPV4_DHCP_HOSTMIN
echo "IPv4-DHCP-HostMax: " $IPV4_DHCP_HOSTMAX

echo "IPv4-Network-Without-Subnet-Prefix: " $IPV4_DHCP_NETWORK_WITHOUT_SUBNET_PREFIX

#Creating bridge and adding interfaces to it.

brctl addbr br0
brctl addif br0 eth0
brctl addif br0 wwan0

#Bring up br0 interface
/usr/sbin/ifconfig br0 up

#Setting new static IP on eth0
/usr/sbin/ip address add "$IPV4_DHCP_HOSTMAX/$IPV4_DHCP_NETMASK" broadcast "$IPV4_DHCP_BROADCAST" dev br0

#Generate DHCP configuration:

sed -i "s/subnet.*/subnet $IPV4_DHCP_NETWORK_WITHOUT_SUBNET_PREFIX netmask $IPV4_DHCP_NETMASK {/" /etc/dhcp/dhcpd.conf
sed -i "s/range.*/range $IPV4_ADDRESS $IPV4_ADDRESS;/" /etc/dhcp/dhcpd.conf
sed -i "s/option domain-name-servers.*/option domain-name-servers $IPV4_DNS_SERVER1, $IPV4_DNS_SERVER2;/" /etc/dhcp/dhcpd.conf
sed -i "s/option broadcast-address.*/option broadcast-address $IPV4_DHCP_BROADCAST;/" /etc/dhcp/dhcpd.conf
sed -i "s/option routers.*/option routers $IPV4_DHCP_HOSTMAX;/" /etc/dhcp/dhcpd.conf

#Restaring DHCP-server
/etc/init.d/isc-dhcp-server restart
