#!/bin/bash
# destroys an lxc container, logical volume, and config files

function usage() {
        echo "$*"
        echo "usage: $0 CONTAINER"
        exit 1
}

source /etc/sysconfig/lxc
CONTAINER=$1
test -z "$CONTAINER" && usage "ERROR: missing CONTAINER name"

ROOT=$GUEST/$CONTAINER
if [ ! -d $ROOT ]; then
        echo "ERROR: container $CONTAINER does not exist"
        exit 1
fi

echo "INFO: destroying lxc container $CONTAINER"
/usr/bin/lxc-destroy -n $CONTAINER

grep $ROOT /proc/mounts && umount $ROOT
sed -i.old -e "/^\/dev\/$GUESTVG\/$CONTAINER/d" /etc/fstab
/sbin/lvs $GUESTVG | grep $CONTAINER
if [ $? -eq 0 ]; then
        echo "INFO: removing logical volume"
        /sbin/lvremove -f /dev/$GUESTVG/$CONTAINER
fi

echo "INFO: removing config files"
rm -f $ETC/$CONTAINER.conf $ETC/$CONTAINER.fstab
rmdir $ROOT

echo "INFO: container $CONTAINER destroyed"
exit 0
