#!/bin/bash
set -eux

# create directories for cri-o
mkdir -p {/var/lib/cni/bin,/etc/kubernetes/cni/net.d,/opt/cni/bin}
chown root:root /var/lib/cni/bin /etc/kubernetes/cni/net.d /opt/cni/bin
chmod 755 /var/lib/cni/bin /etc/kubernetes/cni/net.d /opt/cni/bin

# install packages
yum -y install epel-release

cat > /etc/yum.repos.d/cbs.centos.org_repos_paas7-crio-113-candidate_x86_64_os.repo <<EOL
[cbs.centos.org_repos_paas7-crio-113-candidate_x86_64_os]
name=added from: https://cbs.centos.org/repos/paas7-crio-113-candidate/x86_64/os
baseurl=https://cbs.centos.org/repos/paas7-crio-113-candidate/x86_64/os
enabled=1
gpgcheck=0
EOL

cat > /etc/yum.repos.d/rpms.svc.ci.openshift.org_openshift-origin-v4.2_.repo <<EOL
[rpms.svc.ci.openshift.org_openshift-origin-v4.2_]
name=added from: https://rpms.svc.ci.openshift.org/openshift-origin-v4.2/
baseurl=https://rpms.svc.ci.openshift.org/openshift-origin-v4.2/
enabled=1
gpgcheck=0
EOL

yum update -y

yum -y install git epel-release wget kernel irqbalance microcode_ctl systemd selinux-policy-targeted setools-console dracut-network passwd openssh-server openssh-clients podman skopeo runc containernetworking-plugins cri-tools nfs-utils NetworkManager dnsmasq lvm2 iscsi-initiator-utils sg3_utils device-mapper-multipath xfsprogs e2fsprogs mdadm cryptsetup chrony logrotate sssd shadow-utils sudo coreutils less tar xz gzip bzip2 rsync tmux nmap-ncat net-tools bind-utils strace bash-completion vim-minimal nano authconfig iptables-services biosdevname cloud-utils-growpart glusterfs-fuse cri-o openshift-clients openshift-hyperkube

# enable cri-o
systemctl enable cri-o

# disable swap
swapoff -a

# maskin firewalld, iptables
systemctl mask firewalld iptables

# enable ip forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl --system

# set sebool container_manage_cgroup, disable selinux
setsebool -P container_manage_cgroup on || true
setenforce 0 || true

# create temporary directory and extract contents there
IGNITION_URL=$(cat /opt/ignition_endpoint )
curl -k $IGNITION_URL -o /opt/bootstrap.ign

cat <<EOL > /etc/systemd/system/runignition.service
[Unit]
Description=Run ignition commands
Requires=network-online.target
After=network-online.target

[Service]
ExecStart=/opt/runignition.sh

[Install]
WantedBy=multi-user.target
EOL

chmod 664 /etc/systemd/system/runignition.service
systemctl enable runignition

sed -i '/^.*linux16.*/ s/$/ ip=eno1:dhcp ip=eno2:dhcp rd.neednet=1/' /boot/grub2/grub.cfg
