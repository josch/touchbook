#!/bin/sh -ex

if [ "$FAKEROOTKEY" = "" ]; then
        echo "re-executing script inside fakeroot"
        fakeroot $0;
        exit
fi

DIST="sid"
ROOTDIR="debian-$DIST-multistrap"
#MIRROR="http://127.0.0.1:3142/ftp.de.debian.org/debian"
MIRROR="http://127.0.0.1:3142/ftp.debian-ports.org/debian"
#MIRROR_REAL="http://ftp.de.debian.org/debian"
MIRROR_REAL="http://ftp.debian-ports.org/debian"

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C

rm -rf $ROOTDIR $ROOTDIR.tar

PACKAGES="apt locales less vim wget module-init-tools sysklogd klogd"
PACKAGES=$PACKAGES" procps screen mtd-utils ntpdate conspy man-db console-tools fbset"
PACKAGES=$PACKAGES" input-utils iputils-ping iproute dnsutils wireless-tools curl"
PACKAGES=$PACKAGES" vpnc rsync openssh-server console-setup-mini"
PACKAGES=$PACKAGES" nodm xserver-xorg-input-evdev xserver-xorg-core xterm"
PACKAGES=$PACKAGES" xserver-xorg-video-fbdev mplayer"

cat > multistrap.conf << __END__
[General]
arch=armhf
directory=$ROOTDIR
cleanup=true
unpack=true
noauth=true
bootstrap=Debian_bootstrap Debian_unreleased
aptsources=Debian
allowrecommends=false
addimportant=false

[Debian_bootstrap]
packages=$PACKAGES
source=$MIRROR
suite=$DIST
omitdebsrc=true

[Debian_unreleased]
packages=$PACKAGES
source=$MIRROR
suite=unreleased
omitdebsrc=true

[Debian]
source=$MIRROR_REAL
keyring=debian-archive-keyring
suite=$DIST
omitdebsrc=true
__END__

multistrap -f multistrap.conf

cp /usr/bin/qemu-arm-static $ROOTDIR/usr/bin

# hack to install dash properly
fakechroot chroot $ROOTDIR /var/lib/dpkg/info/dash.preinst install

# keyboard-configuration needs this (initscripts configuration happens afterwards)
fakechroot chroot $ROOTDIR /usr/sbin/update-rc.d mountkernfs.sh start 02 S .

# ifupdown needs this (initscripts configuration happens afterwards)
fakechroot chroot $ROOTDIR /usr/sbin/update-rc.d hostname.sh start 02 S .
fakechroot chroot $ROOTDIR /usr/sbin/update-rc.d mountdevsubfs.sh start 04 S .
fakechroot chroot $ROOTDIR /usr/sbin/update-rc.d checkroot.sh start 10 S .

rename -v 's/(.*)foreign(.*)$/$1$2/' $ROOTDIR/var/lib/dpkg/info/*foreign*

# stop invoke-rc.d from starting services
cat > $ROOTDIR/usr/sbin/policy-rc.d << __END__
#!/bin/sh
echo "sysvinit: All runlevel operations denied by policy" >&2
exit 101
__END__
chmod +x $ROOTDIR/usr/sbin/policy-rc.d

# fix for ldconfig inside fakechroot
mv $ROOTDIR/sbin/ldconfig $ROOTDIR/sbin/ldconfig.REAL
ln -s ../bin/true $ROOTDIR/sbin/ldconfig

# hack to not generate ssh host keys as /dev/urandom is missing
#ssh-keygen -q -f "$ROOTDIR/etc/ssh/ssh_host_rsa_key" -N '' -t rsa
#ssh-keygen -q -f "$ROOTDIR/etc/ssh/ssh_host_dsa_key" -N '' -t dsa
mkdir -p $ROOTDIR/etc/ssh/
touch "$ROOTDIR/etc/ssh/ssh_host_rsa_key"
touch "$ROOTDIR/etc/ssh/ssh_host_dsa_key"
touch "$ROOTDIR/etc/ssh/ssh_host_ecdsa_key"

fakechroot chroot $ROOTDIR /usr/bin/dpkg --configure -a

# creating device nodes that debootstrap creates
#cat > device-table.txt << __END__
##<name>	<type>	<mode>	<uid>	<gid>	<major>	<minor>	<start>	<inc>	<count>
#/dev	d	755	0	0	-	-	-	-	-
#/dev/console	c	0600	0	5	5	1	0	0	-
#/proc/kcore	s	/dev/core	-	-	-	-	-	-	-
#/proc/self/fd	s	/dev/fd	-	-	-	-	-	-	-
#/dev/full	c	0666	0	0	1	7	0	0	-
#/dev/kmem	c	0640	0	15	1	2	0	0	-
#/dev/loop	b	0660	0	6	7	0	0	1	8
#/dev/mem	c	0640	0	15	1	1	0	0	-
#/dev/null	c	0666	0	0	1	3	0	0	-
#/dev/port	c	0640	0	15	1	4	0	0	-
#/dev/ptmx	c	0666	0	5	5	2	0	0	-
#/dev/ram	b	0660	0	6	1	0	0	1	16
#/dev/ram1	s	/dev/ram	-	-	-	-	-	-	-
#/dev/random	c	0666	0	0	1	8	0	0	-
#/proc/self/fd/2	s	/dev/stderr	-	-	-	-	-	-	-
#/proc/self/fd/0	s	/dev/stdin	-	-	-	-	-	-	-
#/proc/self/fd/1	s	/dev/stdout	-	-	-	-	-	-	-
#/dev/tty	c	0666	0	5	5	0	0	0	-
#/dev/tty0	c	0600	0	5	4	0	0	0	-
#/dev/urandom	c	0666	0	0	1	9	0	0	-
#/dev/zero	c	0666	0	0	1	5	0	0	-
#__END__
#
#/usr/share/multistrap/device-table.pl -d $ROOTDIR -f device-table.txt

if [ ! -f modules-omap3-touchbook.tgz ]; then
	curl --silent http://www.alwaysinnovating.com/download/modules-omap3-touchbook.tgz > modules-omap3-touchbook.tgz
fi
tar xzf modules-omap3-touchbook.tgz -C $ROOTDIR

if [ ! -f rt3070_2.1.2.0-r78.5_omap3-touchbook.ipk ]; then
	curl --silent http://www.alwaysinnovating.com/download/rt3070_2.1.2.0-r78.5_omap3-touchbook.ipk > rt3070_2.1.2.0-r78.5_omap3-touchbook.ipk
fi
dpkg-deb --fsys-tarfile rt3070_2.1.2.0-r78.5_omap3-touchbook.ipk | tar xf - -C $ROOTDIR

depmod -a -b $ROOTDIR 2.6.32

#if [ ! -f dsp.tar.gz ]; then
#	curl --silent http://mister-muffin.de/touchbook/dsp.tar.gz > dsp.tar.gz
#fi
#tar xzf dsp.tar.gz -C $ROOTDIR
#
#cat > $ROOTDIR/etc/modules << __END__
#bridgedriver base_img=/lib/dsp/baseimage.dof
#dspbridge
#__END__

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

cat > $ROOTDIR/etc/hosts << __END__
127.0.0.1 localhost
127.0.0.1 touchbook
__END__

sed -i 's/\(root:\)[^:]*\(:\)/\1\/\/plGAV7Hp3Zo\2/' $ROOTDIR/etc/shadow
sed -i 's/\(PermitEmptyPasswords\) no/\1 yes/' $ROOTDIR/etc/ssh/sshd_config
echo 'APT::Install-Recommends "0";' > $ROOTDIR/etc/apt/apt.conf.d/99no-install-recommends
echo 'Acquire::PDiffs "0";' > $ROOTDIR/etc/apt/apt.conf.d/99no-pdiffs

#cleanup
rm $ROOTDIR/sbin/ldconfig
mv $ROOTDIR/sbin/ldconfig.REAL $ROOTDIR/sbin/ldconfig
rm $ROOTDIR/usr/sbin/policy-rc.d
rm $ROOTDIR/etc/ssh/ssh_host_*
cp /etc/resolv.conf $ROOTDIR/etc/resolv.conf

# need to generate tar inside fakechroot so that absolute symlinks are correct
fakechroot chroot $ROOTDIR tar -cf $ROOTDIR.tar -C / .
mv $ROOTDIR/$ROOTDIR.tar .

rm $ROOTDIR/usr/bin/qemu-arm-static

#ls -lha $ROOTDIR/dev
