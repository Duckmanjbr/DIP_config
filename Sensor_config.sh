#!/bin/bash
#
#Info
#============================
#	File: sensor_config.sh
#	Name: Sensor setup and configuration
#
#	VERSION_NUM='1.3'
# 	*version is major.minor format
# 	*major is updated when new capability is added
# 	*minor is updated on fixes and improvements

#History
#============================		
#	29Jun2017 v1.0 
#		Dread Pirate
#		*initial build
#
#	14Jul2017 v1.1
#		Sgt. Mills
#		*added NTP support for sensors
#
#	29Nov2017 v1.2
#		Dread Pirate
#		*Minor bug fixes
#	
#	01Jun2018 v1.3
#		Dread Pirate
#		*added full routing for the sensor through the kit
#
#Description 
#============================
# This script is designed to be run after PMO initial Ghost image of sensor. It loads all the differences needed for kit design. 
#
#
#Notes
#=======================
# https://github.com/Duckmanjbr/DIP_Config/blob/master/Sensor_config.sh
#
#
#============================
#Variables
#
OPENVPN_DIR=/operator/openvpn
#
SENSOR=''
#New sensor interfaces
INTERFACE_1='eno1'
INTERFACE_2='eno2'
#Old Sensor interfaces
OLD_INTERFACE_1='enp6s0'
OLD_INTERFACE_2='enp7s0'
MAC=''
#============================
#
#Check for running script as root
Checkroot()
{
        if [ `whoami` != "root" ]; then
                echo "This Script must be run as root"
                sleep 1
                exit
        fi
}
#===========================
#Sensor version check
Sensor_Version()
{
if (ip a | grep eno > /dev/null); then
	SENSOR='new'
	echo 'New sensor found....'
	sleep 1
elif (ip a | grep enp > /dev/null); then
	SENSOR='old'
	echo 'Old sensor found....'
	n='1'
	for m in $OLD_INTERFACE_1 $OLD_INTERFACE_2; do
		#Get mac address:
		MAC=$(ip link show $m |grep link |cut -d' ' -f 6)
		if grep $m /etc/udev/rules.d/70-persistent-ipoib.rules; then
			sed -i "s/NAME=\".*\",/NAME=\"eno${n}\",/" /etc/udev/rules.d/70-persistent-ipoib.rules
		else
			echo "ACTION==\"add\", SUBSYSTEM==\"net\", DRIVERS==\"?*\", ATTR{type}==\"1\", ATTR{address}==\"$MAC\", NAME=\"eno${n}\"" >> /etc/udev/rules.d/70-persistent-ipoib.rules
			n=$(($n +1))
		fi		
		echo "Lines being written to /etc/udev/rules.d/70-persistent-ipoib.rules for $m....."
		sleep 1
	done
	echo 'This is an old sensor and has been upgraded to use the new interface names.'
fi

}
#
#Create networking files
Files()
{
cd /etc/sysconfig/network-scripts/
for i in $INTERFACE_1 $INTERFACE_2; do
	#If no file exists then create file:
	if [[ ! -e ifcfg-${i} ]]; then
		echo 'TYPE="Ethernet"' > ifcfg-$i
		#If the file is for the 1st interface:
		if [[ $i == $INTERFACE_1 ]]; then
			echo 'BOOTPROTO="dhcp"' >> ifcfg-$i
			echo 'DEVICE="eno1"' >> ifcfg-$i
			echo 'NAME="eno1"' >> ifcfg-$i
			echo 'DEVICE="eno1"' >> ifcfg-$i
			echo "Creating new file ${i} for dynamic config..."
		#If the file is for the 2nd interface:
		elif [[ $i == $INTERFACE_2 ]]; then
			echo 'IPADDR=10.0.0.1' >> ifcfg-$i
			echo 'PREFIX=24' >> ifcfg-$i
			echo 'DEVICE="eno2"' >> ifcfg-$i
			echo 'NAME="eno2"' >> ifcfg-$i
			echo 'DEVICE="eno2"' >> ifcfg-$i
			echo "Creating new file ${i} for staic config..."
		else 
			echo 'Error w/ creating ifcfg-* files'
		fi
		echo 'DEFROUTE="yes"' >> ifcfg-$i
		echo 'IPV4_FAILURE_FATAL="no"' >> ifcfg-$i
		echo 'IPV6INIT="no"' >> ifcfg-$i
		echo 'ONBOOT="yes"' >> ifcfg-$i
	#If file exist then change file:
	elif [[ -e ifcfg-${i} ]]; then
		#If the file is for the 1st interface:
		if [[ $i == $INTERFACE_1 ]]; then
			sed -i "s/.*BOOTPROTO=none.*/BOOTPROTO=DHCP/" ifcfg-$i
			if ( cat /etc/sysconfig/network-scripts/ifcfg-$i |grep IPADDR > /dev/null ); then
				sed -i "/.*IPADDR=*/d" ifcfg-$i
				sed -i "/.*PREFIX=*/d" ifcfg-$i
			fi
			echo "Changing file ${i} for dynamic config..."
		#If the file is for the 2nd interface:
		elif [[ $i == $INTERFACE_2 ]]; then
			sed -i "s/.*BOOTPROTO=dhcp.*/BOOTPROTO=none/" ifcfg-$i
			if ( cat /etc/sysconfig/network-scripts/ifcfg-$i |grep IPADDR > /dev/null ); then
				sed -i "/.*IPADDR=*/d" ifcfg-$i
				sed -i "/.*PREFIX=*/d" ifcfg-$i
				echo 'IPADDR=10.0.0.1' >> ifcfg-$i
				echo 'PREFIX=24' >> ifcfg-$i
			else
				echo 'IPADDR=10.0.0.1' >> ifcfg-$i
				echo 'PREFIX=24' >> ifcfg-$i
			fi
			echo "Changing file ${i} for staic config..."
		else
			echo 'Error w/ changing existing network ifcfg-* files'
		fi
		sed -i "s/.*ONBOOT=no.*/ONBOOT=yes/" ifcfg-$i
		sed -i "s/.*IPV6INIT=yes*/IPV6INIT=no/" ifcfg-$i
	fi
	echo "Added lines of code to /etc/sysconfig/network-scripts/ifcfg-${i}"
done
#Change sshd_config
sed -i "s/.*#PermitRootLogin\ yes.*/PermitRootLogin\ no/" /etc/ssh/sshd_config 
sed -i "s/.*#Protocol\ 2.*/Protocol\ 2/" /etc/ssh/sshd_config
echo "Changed sshd_config ... "
# Turn on networking @ startup
echo "NETWORKING=yes" >> /etc/sysconfig/network
echo "IPV6INIT=no" >> /etc/sysconfig/network
echo "Turned on networking in /etc/sysconfig/network...  "
}
#===========================
#Setup OpenVPN configuration
Open_VPN()
{
if [[ ! -d $OPENVPN_DIR ]]; then
	mkdir -p $OPENVPN_DIR
	chown :assessor $OPENVPN_DIR -R
	chmod 775 $OPENVPN_DIR -R
	echo 'Directories created for VPN'
fi
#check for pre-existing file:
if [[ -f /$OPENVPN_DIR/run.sh ]];then
	echo "VPN run.sh file already exists!"
else
	touch $OPENVPN_DIR/run.sh
	echo '#!/bin/bash' > $OPENVPN_DIR/run.sh
	echo "sudo dhclient -r tap0" >> $OPENVPN_DIR/run.sh
	echo "sudo dhclient tap0 &" >> $OPENVPN_DIR/run.sh
	sudo chmod 4775 $OPENVPN_DIR/run.sh
	echo "Created file: $OPENVPN_DIR/run.sh"
fi
#Setup tap0 interface:
if [[ -f /etc/sysconfig/network-scripts/ifcfg-tap0 ]];then
	echo 'ifcfg-tap0 file already exists!'
elif [[ ! -f /etc/sysconfig/network-scripts/ifcfg-tap0 ]];then
	echo -e "NAME=\"tap0\" \nDEVICE=\"tap0\" \nONBOOT=\"no\" \nTYPE=\"eth\" \nBOOTPROTO=\"dhcp\" \nPERSISTENT_DHCLIENT=1 \nHOTPLUG=\"yes\" \nDEFROUTE=\"yes\" \nPEERDNS=\"yes\" \nPEERROUTES=\"yes\" \nIPV4_FAILURE_FATAL=\"no\" \nIPV6INIT=\"no\"" > /etc/sysconfig/network-scripts/ifcfg-tap0
fi
}
#==========================
#NTP config
Ntp()
{
sed -ri "/server\ [0-3].rhel/ d" /etc/ntp.conf
sed -i "s/.*keys\ \/etc\/ntp\/keys/#keys\ \/etc\/ntp\/keys/" /etc/ntp.conf
sed -i "s/.*includefile\ \/etc\/ntp\/crypto\/pw/#includefile\ \/etc\/ntp\/crypto\/pw/" /etc/ntp.conf
echo 'ntp.conf rewritten.....'
systemctl enable ntpdate.service
systemctl daemon-reload
timedatectl set-timezone UTC
if ( route -n |grep 37.1 );then
	systemctl stop ntpd
	ntpd -gq
	systemctl start ntpd
else
	echo 'You must sync time once the network is set up!'
	sleep 2
fi
}

#Change Hostname
Hostn()
{
echo ''
read -p "Do you need to change the Hostname? [y/n] " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]];then
	echo ''
	read -p "What would you like the Hostname to be?  " NAME
	echo ''
	read -p "Is $NAME the correct Hostname? [y/n]  " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]];then
		hostnamectl set-hostname ${NAME}.dmss
	fi
fi
}
#==========================
#Change Passwd
Passwords()
{
echo ''
read -p "Would you like to change passwords?  [y/n]  " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]];then
	passwd root
	passwd assessor
fi
}
#=========================
#Reboot Sensor
Restart()
{
echo ''
read -p "Would you like to reboot now?  [y/n]  " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]];then
	/usr/sbin/shutdown -r now
else
	clear
	echo ''
	echo "Remember to reboot Sensor before use!!"
fi
}
#=========================
#Run Script 
clear
Checkroot
Sensor_Version
Files
Open_VPN
Ntp
Hostn
Passwords
Restart
