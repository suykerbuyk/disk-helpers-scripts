#!/bin/sh

populate_pacman_conf() {
(
cat <<'PACMAN_CONF'
#
# /etc/pacman.conf
#
# See the pacman.conf(5) manpage for option and repository directives

#
# GENERAL OPTIONS
#
[options]
# The following paths are commented out with their default values listed.
# If you wish to use different paths, uncomment and update the paths.
#RootDir     = /
#DBPath      = /var/lib/pacman/
#CacheDir    = /var/cache/pacman/pkg/
#LogFile     = /var/log/pacman.log
#GPGDir      = /etc/pacman.d/gnupg/
#HookDir     = /etc/pacman.d/hooks/
HoldPkg     = pacman glibc
#XferCommand = /usr/bin/curl -L -C - -f -o %o %u
#XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
#CleanMethod = KeepInstalled
Architecture = auto

# Pacman won't upgrade packages listed in IgnorePkg and members of IgnoreGroup
#IgnorePkg   =
#IgnoreGroup =

#NoUpgrade   =
#NoExtract   =

# Misc options
#UseSyslog
#Color
#NoProgressBar
CheckSpace
#VerbosePkgLists
#ParallelDownloads = 5

# By default, pacman accepts packages signed by keys that its local keyring
# trusts (see pacman-key and its man page), as well as unsigned packages.
SigLevel    = Never DatabaseOptional
LocalFileSigLevel = Optional
#RemoteFileSigLevel = Required

# NOTE: You must run `pacman-key --init` before first using pacman; the local
# keyring can then be populated with the keys of all official Arch Linux
# packagers with `pacman-key --populate archlinux`.

#[testing]
#Include = /etc/pacman.d/mirrorlist

# mirrorslist could also be:
#Server = http://repo.lyve.colo.seagate.com/arch/$repo/os/$arch

[archzfs]
Server = http://repo.lyve.colo.seagate.com/$repo/$arch/

[zfs-linux-kernel]
Server = http://repo.lyve.colo.seagate.com/kernels.archzfs/$repo/

[zfs-linux-lts-kernel]
Server = http://repo.lyve.colo.seagate.com/kernels.archzfs/$repo/

[core]
Server = http://repo.lyve.colo.seagate.com/arch/$repo/os/$arch/
#Include = /etc/pacman.d/mirrorlist

[extra]
Server = http://repo.lyve.colo.seagate.com/arch/$repo/os/$arch/
#Include = /etc/pacman.d/mirrorlist

#[community-testing]
#Include = /etc/pacman.d/mirrorlist

[community]
Server = http://repo.lyve.colo.seagate.com/arch/$repo/os/$arch/
#Include = /etc/pacman.d/mirrorlist

# If you want to run 32 bit applications on your x86_64 system,
# enable the multilib repositories as required here.

#[multilib-testing]
#Include = /etc/pacman.d/mirrorlist

#[multilib]
#Include = /etc/pacman.d/mirrorlist
PACMAN_CONF
)>/etc/pacman.conf
}

add_arch_zfs_keys() {
pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman-key --lsign DDF7DB817396A49B2A2723F7403BD972F75D9D76
}

populate_pacman_mirrors() {
(
cat <<'PACMAN_CONF'
Server = http://repo.lyve.colo.seagate.com/arch/$repo/os/$arch
#  ## United States
#  Server = https://iad.mirrors.misaka.one/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://arch.hu.fo/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.kaminski.io/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://arch.mirror.square-r00t.net/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.radwebhosting.com/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.ocf.berkeley.edu/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://ftp.sudhip.com/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.wdc1.us.leaseweb.net/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.rit.edu/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.phx1.us.spryservers.net/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://repo.ialab.dsu.edu/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.pit.teraswitch.com/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://arlm.tyzoid.com/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.lug.mtu.edu/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.rutgers.edu/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.sonic.net/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://zxcvfdsa.com/arch/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.xtom.com/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.clarkson.edu/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://america.mirror.pkgbuild.com/$repo/os/$arch
#  ## United States
#  Server = https://mirror.lty.me/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.mia11.us.leaseweb.net/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.dal10.us.leaseweb.net/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.hackingand.coffee/arch/$repo/os/$arch
#  ## United States
#  Server = https://archmirror1.octyl.net/$repo/os/$arch
#  ## United States
#  Server = https://mirror.arizona.edu/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.sfo12.us.leaseweb.net/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.ette.biz/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://arch.mirror.constant.com/$repo/os/$arch
#  ## United States
#  Server = https://ord.mirror.rackspace.com/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirror.theash.xyz/arch/$repo/os/$arch
#  ## United States
#  Server = https://mirror.stephen304.com/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://plug-mirror.rcac.purdue.edu/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://dfw.mirror.rackspace.com/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://iad.mirror.rackspace.com/archlinux/$repo/os/$arch
#  ## United States
#  Server = https://mirrors.mit.edu/archlinux/$repo/os/$arch
PACMAN_CONF
)>/etc/pacman.d/mirrorlist
}

populate_pacman_conf
populate_pacman_mirrors
add_arch_zfs_keys
#DEV=/dev/sda ;for X in $(ls ${DEV}[1\|2\|3\|4]) ; do wipefs -a ${X}; done; sgdisk --zap-all ${DEV}; dd if=/dev/zero of=${DEV}bs=1M count=4096 oflag=sync
#archinstall --config=http://mgmt.lyve.colo.seagate.com/repo/helpers/arch.install.config.json
#for X in $(ls /boot/loader/entries/*.conf); do sed -i '/^option/ s/$/console=ttyS0,115200n8 text debug log.nologo/' ${X} ; done
#sed -i  's/.*UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config
#sed -i  's/.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
