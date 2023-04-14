#!/bin/bash
#This is a poor programmed script for creating an IP-Passtrough bridge for mobile connections. 

#Setting up mobile broadband connection
sleep 10
mmcli --scan-modems
sleep 5
mmcli -m 0 --set-allowed-modes='4g'
sleep 5
mmcli -m 0 --enable
sleep 5
mmcli -m 0 --simple-connect='apn=telenor.fwa,ip-type=ipv4'
sleep 5

#Setting up wwan0 and eht0 interfaces
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

IPCalc "30"
if [[ $IPV4_DHCP_HOSTMIN == $IPV4_ADDRESS || $IPV4_DHCP_HOSTMAX == $IPV4_ADDRESS ]] && [ $IPV4_DHCP_BROADCAST != $IPV4_ADDRESS ]; then
   echo "IP-en kan brukes i /30"
   IPV4_Caclulator_Subnet="/30"
   else
      echo "/30 kan ikke brukes, sjekker /29"
      IPCalc "29"
      if [[ $IPV4_ADDRESS != $IPV4_DHCP_BROADCAST ]]; then
          echo "$IPV4_ADDRESS kan brukes i /29"
          IPV4_Caclulator_Subnet="/29"
      else IPCalc "28"
           if [[ $IPV4_ADDRESS != $IPV4_DHCP_BROADCAST ]]; then
               echo "$IPV4_ADDRESS kan brukes i /28"
               IPV4_Caclulator_Subnet="/28"
           else IPCalc "27"
                if [[ $IPV4_ADDRESS != $IPV4_DHCP_BROADCAST ]]; then
                    echo "$IPV4_ADDRESS kan brukes i /27"
                    IPV4_Caclulator_Subnet="/27"
                else IPCalc "26"
                     if [[ $IPV4_ADDRESS != $IPV4_DHCP_BROADCAST ]]; then
                     echo "$IPV4_ADDRESS kan brukes i /26"
                     IPV4_Caclulator_Subnet="/26"
                     else IPCalc "25"
                          if [[ $IPV4_ADDRESS != $IPV4_DHCP_BROADCAST ]]; then
                          echo "$IPV4_ADDRESS kan brukes i /25"
                          IPV4_Caclulator_Subnet="/25"
                          else echo "Bruker /24-subnett"
                               IPV4_Caclulator_Subnet="/24"
                          fi
                    fi
                fi
            fi
       fi
fi
echo "Sjekker host min og host max i $IPV4_Caclulator_Subnet subnet"
if [[ $IPV4_ADDRESS != $IPV4_DHCP_HOSTMIN ]]
   then
   echo "OK, IPV4-Adressen er ikke minst i subnettet, Gateway er god."
   IPV4_GATEWAY=$IPV4_DHCP_HOSTMIN
   echo "Gateway: $IPV4_GATEWAY, IP: $IPV4_ADDRESS"
else
   echo "Gateway blir host-max"
   IPV4_GATEWAY=$IPV4_DHCP_HOSTMAX
   echo "Gateway: $IPV4_GATEWAY, IP: $IPV4_ADDRESS"
fi

#Setting bridge interface and IP
brctl addbr br0
brctl addif br0 eth0
brctl addif br0 wwan0
ifconfig br0 up

/usr/sbin/ip address add "$IPV4_GATEWAY/$IPV4_DHCP_NETMASK" broadcast "$IPV4_DHCP_BROADCAST" dev br0

#Generate DHCP configuration:
IPV4_DHCP_NETWORK_WITHOUT_SUBNET_PREFIX=${IPV4_DHCP_NETWORK%/*}

echo "IPv4-DHCP-Network: " $IPV4_DHCP_NETWORK
echo "IPv4-DHCP-Netmask: " $IPV4_DHCP_NETMASK
echo "IPv4-DHCP-HostMin: " $IPV4_DHCP_HOSTMIN
echo "IPv4-DHCP-HostMax: " $IPV4_DHCP_HOSTMAX
echo "IPv4-Network-Without-Subnet-Prefix: " $IPV4_DHCP_NETWORK_WITHOUT_SUBNET_PREFIX

sed -i "s/subnet.*/subnet $IPV4_DHCP_NETWORK_WITHOUT_SUBNET_PREFIX netmask $IPV4_DHCP_NETMASK {/" /etc/dhcp/dhcpd.conf
sed -i "s/range.*/range $IPV4_ADDRESS $IPV4_ADDRESS;/" /etc/dhcp/dhcpd.conf
sed -i "s/option domain-name-servers.*/option domain-name-servers $IPV4_DNS_SERVER1, $IPV4_DNS_SERVER2;/" /etc/dhcp/dhcpd.conf
#sed -i "s/option broadcast-address.*/option broadcast-address $IPV4_DHCP_BROADCAST;/" /etc/dhcp/dhcpd.conf
sed -i "s/option routers.*/option routers $IPV4_GATEWAY;/" /etc/dhcp/dhcpd.conf

#Restaring DHCP-server
/etc/init.d/isc-dhcp-server restart
