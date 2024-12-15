set -e
set -x
os=${2:-debian}
arch=i386
suite=${1:-trixie}
chroot_dir="/var/chroot/$suite-$arch"
ubuntu_apt_mirror='http://fr.archive.ubuntu.com/ubuntu'
apt_mirror='http://mirrors.hosterion.ro/debian/'
docker_image="corpusops/$os-32:$suite"
debian_packages="
build-essential \
cargo \
debhelper \
debootstrap \
dpkg-dev \
gcc \
gnupg \
libbluetooth-dev \
libbz2-dev \
libc6-dev \
libdb-dev \
libexpat1-dev \
libffi-dev \
libgdbm-dev \
liblzma-dev \
libncursesw5-dev \
libreadline-dev \
libsqlite3-dev \
libssl-dev \
make \
netbase \
python3 \
tk-dev \
tzdata \
uuid-dev \
vim \
wget \
xz-utils \
zlib1g-dev \
"
case $os in
    debian)
	packages="$debian_packages"

        ;;
    *)
        echo "$os not supported"
        exit 1
esac
export DEBIAN_FRONTEND=noninteractive
if [ ! -e $chroot_dir/bin/ls ];then
    debootstrap --verbose --no-check-gpg --variant=minbase --arch=$arch $suite $chroot_dir $apt_mirror
fi
cp /etc/resolv.conf $chroot_dir/etc/resolv.conf
if [ ! -e $chroot_dir/proc/1 ];then
    mount -o bind /proc $chroot_dir/proc
fi

cat <<EOF > $chroot_dir/etc/apt/sources.list
deb     $apt_mirror $suite main contrib non-free non-free-firmware
deb-src $apt_mirror $suite  main contrib non-free non-free-firmware
deb     $apt_mirror ${suite}-updates main contrib non-free non-free-firmware
deb-src $apt_mirror ${suite}-updates main contrib non-free non-free-firmware
EOF
chroot $chroot_dir apt-get update
chroot $chroot_dir apt-get -y upgrade
chroot $chroot_dir apt-get -y install $packages
chroot $chroot_dir apt-get autoclean
chroot $chroot_dir apt-get clean
chroot $chroot_dir apt-get autoremove
chroot $chroot_dir rm -rfv /var/lib/apt/lists/*
rm $chroot_dir/etc/resolv.conf
chroot_pids=$(for p in /proc/*/root; do ls -l $p; done | grep $chroot_dir | cut -d'/' -f3)
test -z "$chroot_pids" || (for p in $chroot_pids;do kill -9 $p || true;done; sleep 2)
if [ -e $chroot_dir/proc/1 ]; then umount $chroot_dir/proc;fi
tar cfz ${os}-${suite}.tgz -C $chroot_dir .
cat ${os}-${suite}.tgz | docker import - $docker_image --message "Build with https://github.com/docker-32bit/ubuntu"
echo "For cleanup, you can rm -rf $chroot_dir ${os}-${suite}.tgz"
