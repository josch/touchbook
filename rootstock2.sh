#!/bin/sh -e

DIST="sid"
ROOTDIR="debian-$DIST-cdebootstrap"
MIRROR="http://localhost:3142/ftp.de.debian.org/debian"

rm -rf $ROOTDIR $ROOTDIR.tar $ROOTDIR.squashfs

cdebootstrap --flavour=minimal --foreign --arch=armel $DIST $ROOTDIR $MIRROR

cp /usr/bin/qemu-arm-static $ROOTDIR/usr/bin

#chroot $ROOTDIR /debootstrap/debootstrap --second-stage
chroot $ROOTDIR /sbin/cdebootstrap-foreign

chroot $ROOTDIR apt-get update
chroot $ROOTDIR apt-get install locales udev module-init-tools sysklogd klogd procps mtd-utils ntpdate debconf-english \
				screen less vim-tiny console-tools conspy console-setup-mini man-db fbset input-utils \
				iputils-ping iproute dnsutils curl wget openssh-server vpnc rsync wireless-tools \
				wpasupplicant xserver-xorg-video-omapfb xserver-xorg-video-fbdev xserver-xorg-input-evdev \
				xserver-xorg -qq
chroot $ROOTDIR apt-get remove cdebootstrap-helper-rc.d -qq

curl http://www.alwaysinnovating.com/download/modules-omap3-touchbook.tgz | tar xzf - -C $ROOTDIR
wget http://www.alwaysinnovating.com/download/rt3070_2.1.2.0-r78.5_omap3-touchbook.ipk
ar x rt3070_2.1.2.0-r78.5_omap3-touchbook.ipk
tar xzf data.tar.gz -C $ROOTDIR
rm rt3070_2.1.2.0-r78.5_omap3-touchbook.ipk data.tar.gz control.tar.gz debian-binary

chroot $ROOTDIR depmod -a 2.6.32

rm $ROOTDIR/usr/bin/qemu-arm-static

sed -i 's/\(root:\)[^:]*\(:\)/\1\/\/plGAV7Hp3Zo\2/' $ROOTDIR/etc/shadow

sed -i 's/\(PermitEmptyPasswords\) no/\1 yes/' $ROOTDIR/etc/ssh/sshd_config

echo 'APT::Install-Recommends "0";' > $ROOTDIR/etc/apt/apt.conf.d/99no-install-recommends

mv $ROOTDIR/sbin/init.REAL $ROOTDIR/sbin/init

mkdir $ROOTDIR/mnt/mmcblk0p1
mkdir $ROOTDIR/mnt/mmcblk0p2

cat > $ROOTDIR/etc/fstab << __END__
# <file system> <mount point>    <type> <options>                          <dump> <pass>
rootfs          /                auto   defaults,errors=remount-ro,noatime 0      1
/dev/mmcblk0p1  /mnt/mmcblk0p1   auto   defaults,errors=remount-ro,noatime 0      2
/dev/mmcblk0p2  /mnt/mmcblk0p2   auto   defaults,errors=remount-ro,noatime 0      2
proc            /proc            proc   defaults                           0      0
tmpfs           /tmp             tmpfs  defaults,noatime                   0      0
tmpfs           /var/lock        tmpfs  defaults,noatime                   0      0
tmpfs           /var/run         tmpfs  defaults,noatime                   0      0
tmpfs           /var/log         tmpfs  defaults,noatime                   0      0
tmpfs           /etc/network/run tmpfs  defaults,noatime                   0      0
/dev/mmcblk0p3  swap             swap   defaults                           0      0
__END__

echo touchbook > $ROOTDIR/etc/hostname

echo deb http://ftp.debian.org $DIST main > $ROOTDIR/etc/apt/sources.list

cat > $ROOTDIR/etc/hosts << __END__
127.0.0.1 localhost
127.0.0.1 touchbook
__END__

curl http://mister-muffin.de/touchbook/dsp.tar.gz | tar xzf - -C $ROOTDIR

cat > $ROOTDIR/etc/modules << __END__
bridgedriver base_img=/lib/dsp/baseimage.dof
dspbridge
__END__

tar -cf $ROOTDIR.tar -C $ROOTDIR .
mksquashfs $ROOTDIR $ROOTDIR.squashfs
