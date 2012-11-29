#!/bin/bash
# create a compressed tar file containing the base lxc guest filesystem

# initialize
CONFIG=/etc/sysconfig/lxc
if [ ! -r $CONFIG ]; then
        echo "ERROR: $CONFIG not found"
        exit 1
fi
source $CONFIG

# if the base dir already exists, leave it alone, otherwise create it
if [ ! -d $GUEST/base ]; then
        echo "INFO: creating $GUEST/base"

        mkdir -m 755 $GUEST/base
        /sbin/lvcreate --size 10G --name base $GUESTVG
        DEV=/dev/$GUESTVG/base
        /sbin/mkfs.ext3 $DEV
        echo "INFO: adding $GUEST/base to host's /etc/fstab"
        echo "$DEV $GUEST/base ext3 defaults 1 3" >> /etc/fstab
        echo "INFO: mounting $GUEST/base"
        mount $GUEST/base

	# stream tarred filesystem minus what's specified in exclude file to base dir 
        tar --numeric-owner -c -f - -X $ETC/tarexclude / | tar -x -C $GUEST/base -f -

        # automate customize image for lxc virtual clients
        echo "INFO: cleaning up $GUEST/base"

        # fix /dev
        DEV=$GUEST/base/dev
        rm -rf ${DEV}
        mkdir -m 755 ${DEV}
        mknod -m 666 ${DEV}/null c 1 3
        mknod -m 666 ${DEV}/zero c 1 5
        mknod -m 666 ${DEV}/random c 1 8
        mknod -m 666 ${DEV}/urandom c 1 9
        mkdir -m 755 ${DEV}/pts
        mkdir -m 1777 ${DEV}/shm
        mknod -m 666 ${DEV}/tty c 5 0
        mknod -m 666 ${DEV}/tty0 c 4 0
        mknod -m 666 ${DEV}/tty1 c 4 1
        mknod -m 666 ${DEV}/tty2 c 4 2
        mknod -m 666 ${DEV}/tty3 c 4 3
        mknod -m 666 ${DEV}/tty4 c 4 4
        mknod -m 600 ${DEV}/console c 5 1
        mknod -m 666 ${DEV}/full c 1 7
        mknod -m 600 ${DEV}/initctl p
        mknod -m 666 ${DEV}/ptmx c 5 2

        DOMAIN=`hostname --domain`
        sed -i -e "/^HOSTNAME=/s/^.*$/HOSTNAME=base.$DOMAIN/" $GUEST/base/etc/sysconfig/network

        # this comment lets the console watcher know to stop watching
        echo 'echo "INFO: container `hostname -s` started"' >> $GUEST/base/etc/rc.local

        sed -i.orig -e "\/sbin\/start_udev/s/^/#/" $GUEST/base/etc/rc.d/rc.sysinit

        cp /dev/null $GUEST/base/etc/fstab

        SETUP_ROOTPATH=/root/setup.sh
        SETUP=$GUEST/base/$SETUP_ROOTPATH
        cat <<EOM >>$SETUP
#!/bin/bash
exec >/root/setup.log 2>&1
CONTAINER=$1
echo "INFO: disabling uncommon system services"
chroot /lxc/guest/$CONTAINER <<EOM
chkconfig acpid off
chkconfig auditd off
chkconfig kudzu off
chkconfig microcode_ctl off
chkconfig autofs off
chkconfig hidd off
chkconfig auditd off
chkconfig ip6tables off
chkconfig isdn off
chkconfig gpm off
chkconfig cups off
chkconfig sendmail off
chkconfig rpcidmapd off
chkconfig rpcgssd off
chkconfig netfs off
chkconfig nfslock off
chkconfig portmap off

exit 0
EOM

        # run setup.sh inside the container
        # see chroot works great with containers
        chmod +x $SETUP
        /usr/sbin/chroot $GUEST/base $SETUP_ROOTPATH
fi

echo "INFO: done"
exit 0
