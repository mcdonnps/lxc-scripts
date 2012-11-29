#!/bin/bash
# creates lxc container for use in a chef-managed environment 

function usage() {
        echo "$*"
        echo "usage: $0 CONTAINER SIZE IPADDR PREFIX GATEWAY CHEFROLE CHEFUSER (VG)"
        echo "eg: create.sh bob0001 29G 192.168.1.11 24 192.168.1.1 Bob auto vg1"
        exit 1
}

# process required command line arguments
CONTAINER=$1
SIZE=$2
IPADDR=$3
PREFIX=$4
GATEWAY=$5
CHEFROLE=$6
CHEFUSER=$7
VG=$8

# this script sets env vars ETC, GUEST, GUESTVG
source /etc/sysconfig/lxc

test -z "$CONTAINER" && usage "ERROR: missing CONTAINER name"
test -z "$SIZE" && usage "ERROR: missing SIZE (eg 29G)"
test -z "$IPADDR" && usage "ERROR: missing IPADDR"
test -z "$PREFIX" && usage "ERROR: missing PREFIX"
test -z "$GATEWAY" && usage "ERROR: missing GATEWAY"
test -z "$CHEFROLE" && usage "ERROR: missing CHEFROLE"
test -z "$CHEFUSER" && usage "ERROR: missing CHEFUSER"
test -z "$VG" && VG=$GUESTVG && usage "WARNING: no volume group supplied, using default (found in /etc/sysconfig/lxc)"
# could stand to do a little better input validation here

ROOT=$GUEST/$CONTAINER
echo "INFO: request to create a new container named \"$CONTAINER\""
echo "INFO: logical volume will be created as $VG/$CONTAINER, size $SIZE"
echo "INFO: which will be mounted as $ROOT on the lxc host"
echo "INFO: the IP assigned this container is $IPADDR/$PREFIX"
echo "INFO: default gateway will be $GATEWAY"

if [ -d $ROOT ]; then
        echo "ERROR: ${CONTAINER}'s filesystem $ROOT already exists"
        exit 1
fi

# calculate a unique MAC addresses based on the hexification of the IP address.
MACADDR=`printf "02:00:%x:%x:%x:%x" ${IPADDR//./ }`

# path to the lxc container configuration file
CONF=$ETC/$CONTAINER.conf

# path to the lxc container filesystem table
# these filesystems get mounted by the HOST, before "boot time"
# anything in /lxc/guest/container/etc/fstab
# gets mounted during "boot" by the container.
FSTAB=$ETC/$CONTAINER.fstab

echo "INFO: `date` creating $ROOT"
mkdir $ROOT
/sbin/lvcreate --size $SIZE --name $CONTAINER $VG
echo "INFO: creating ext3 file system on $ROOT"
/sbin/mkfs.ext3 /dev/$VG/$CONTAINER
echo "INFO: mounting $ROOT"
echo "/dev/$VG/$CONTAINER $ROOT ext3 defaults 1 3" >> /etc/fstab
/bin/mount $ROOT

echo "INFO: rsyncing $BASE/ into $ROOT/"
rsync -a $BASE/ $ROOT/

# delete from here to...
echo "INFO: generating client-attribs.json"
echo "{ \"chef_environment\": \"yourenv\", \"user\": \"$CHEFUSER\", \"run_list\": [ \"role[$CHEFROLE]\" ] }" > $ROOT/etc/chef/client-attribs.json

echo "INFO: deleting old client.pem"
rm -f $ROOT/etc/chef/client.pem

echo "INFO: replacing client.rb"
wget http://cobblerhost/cobbler/aux/client.rb -O $ROOT/etc/chef/client.rb
# here if you don't use chef

echo "INFO: adding default route to $ROOT/etc/rc.local"
echo "/sbin/route add default gw $GATEWAY" >> $ROOT/etc/rc.local

echo "INFO: setting hostname"
DOMAIN=`/bin/hostname --domain`
sed -i -e "/^HOSTNAME=/s/^.*$/HOSTNAME=$CONTAINER.vm.$DOMAIN/" $ROOT/etc/sysconfig/network

echo "INFO: configuring networking"
rm -f $ROOT/etc/sysconfig/network-scripts/ifcfg-br* $ROOT/etc/sysconfig/network-scripts/ifcfg-eth* $ROOT/etc/sysconfig/network-scripts/route-*

echo "INFO: creating $FSTAB"
cat <<EOM >>$FSTAB
none $ROOT/dev/pts    devpts defaults 0 0
none $ROOT/proc    proc    defaults 0 0
none $ROOT/sys    sysfs    defaults 0 0
EOM

echo "INFO: creating $CONF"
cat <<EOM >>$CONF
#
# LXC container configuration file
#
# container name
lxc.utsname = $CONTAINER
#
# how many tty consoles to create
lxc.tty = 4
#
# full path to the container's root filesystem
lxc.rootfs = $ROOT
#
# full path to the container.fstab config file
lxc.mount = $FSTAB
#
# create one network interface
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = br0
lxc.network.name = eth0
lxc.network.mtu = 1500
lxc.network.hwaddr = $MACADDR
lxc.network.ipv4 = $IPADDR/$PREFIX
#
# which cpus can this container use?
# run: /lxc/bin/lxc-cgroup -n container cpuset.cpus
# to display the current value
#lxc.cgroup.cpuset.cpus = 0
#
# which devices can this container access?
# deny to all by default
lxc.cgroup.devices.deny = a
# allow /dev/null and zero
lxc.cgroup.devices.allow = c 1:3 rwm
lxc.cgroup.devices.allow = c 1:5 rwm
# allow consoles
lxc.cgroup.devices.allow = c 5:1 rwm
lxc.cgroup.devices.allow = c 5:0 rwm
lxc.cgroup.devices.allow = c 4:0 rwm
lxc.cgroup.devices.allow = c 4:1 rwm
# allow /dev/{,u}random
lxc.cgroup.devices.allow = c 1:9 rwm
lxc.cgroup.devices.allow = c 1:8 rwm
# allow /dev/pts/* - pts namespaces are "coming soon"
lxc.cgroup.devices.allow = c 136:* rwm
lxc.cgroup.devices.allow = c 5:2 rwm
# allow rtc
lxc.cgroup.devices.allow = c 254:0 rwm
EOM

echo "INFO: creating container $CONTAINER"
/usr/bin/lxc-create -n $CONTAINER -f $CONF

echo "INFO: done"
exit 0
