#!/bin/bash
# starts an lxc container

source /etc/sysconfig/lxc
CONTAINER=$1
ROOT=$GUEST/$CONTAINER
if [ ! -d $ROOT ]; then
        echo "container root directory $ROOT not found"
        exit 1
fi
if [ ! -d $ROOT/root ]; then
        /bin/mount /dev/$GUESTVG/$CONTAINER $ROOT
fi

echo "`date` container $CONTAINER booting"
/usr/bin/lxc-start -d -n $CONTAINER
exit 0
