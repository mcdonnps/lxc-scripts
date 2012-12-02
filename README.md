lxc-scripts
===========

LXC management scripts for EL6 largely based upon Patrick Wolfe's scripts (http://www.whistl.com/files/lxcmgmt.tgz) and accompanying blog post (http://whistl.com/blogs/index.php/blog/?p=416&more=1&c=1&tb=1&pb=1).

These scripts assume you are using LXC in an LVM environment and are using Chef for configuration management.

Setup:

```% mkdir -p /lxc/{bin,etc}
% cp {clone,create,destroy,start}.sh /lxc/bin
% chmod 755 /lxc/bin/*.sh
% cp lxc.sysconfig /etc/sysconfig/lxc
% cp tarexclude /lxc/etc/```

Configuration:

Modify the variables in /etc/sysconfig/lxc to taste.  /lxc/etc/tarexclude contains a basic set of files and directories to exclude but may also be modified.  Lastly, check to make sure create.sh is handling Chef configuration appropriately for your environment.

Usage:

```% /lxc/bin/clone.sh # Clones the root filesystem and creates a golden base volume in the specified LVM volume group
% /lxc/bin/create.sh CONTAINER SIZE IPADDR PREFIX GATEWAY CHEFROLE CHEFUSER <VG> # Creates a new container from the golden volume in a new logical volume
% /lxc/bin/destroy.sh CONTAINER # Destroys target container, logical volume, and removes from fstab
% /lxc/bin/start.sh CONTAINER # Starts target container (wrapper around lxc-start)```

The creation process can be tedious if run by hand.  At Etsy, we have integrated create.sh into our internal VM creation portal.  You may want to place a similar wrapper around it.
