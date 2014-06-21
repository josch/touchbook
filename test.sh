#!/bin/sh -ex

DIST="sid"
ROOTDIR="debian-$DIST-multistrap"
MIRROR="http://127.0.0.1:3142/ftp.de.debian.org/debian"

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C

rm -rf $ROOTDIR $ROOTDIR.tar

PACKAGES="udev"

cat > multistrap.conf << __END__
[General]
arch=armel
directory=$ROOTDIR
cleanup=true
unpack=true
noauth=true
bootstrap=Debian
aptsources=Debian
allowrecommends=false
addimportant=false

[Debian]
packages=$PACKAGES
source=$MIRROR
keyring=debian-archive-keyring
suite=$DIST
omitdebsrc=true
__END__

multistrap -f multistrap.conf

cp /usr/bin/qemu-arm-static $ROOTDIR/usr/bin

fakechroot chroot $ROOTDIR /var/lib/dpkg/info/dash.preinst install

cat > $ROOTDIR/usr/sbin/policy-rc.d << __END__
#!/bin/sh
echo "sysvinit: All runlevel operations denied by policy" >&2
exit 101
__END__
chmod +x $ROOTDIR/usr/sbin/policy-rc.d

mv $ROOTDIR/sbin/ldconfig $ROOTDIR/sbin/ldconfig.REAL
ln -s ../bin/true $ROOTDIR/sbin/ldconfig

fakechroot chroot $ROOTDIR /usr/bin/dpkg --configure -a

rm $ROOTDIR/sbin/ldconfig
mv $ROOTDIR/sbin/ldconfig.REAL $ROOTDIR/sbin/ldconfig
rm $ROOTDIR/usr/sbin/policy-rc.d
rm $ROOTDIR/usr/bin/qemu-arm-static
