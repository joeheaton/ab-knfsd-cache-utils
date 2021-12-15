#!/bin/bash
#
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Exit on command failure
set -e

# Set shell color variables
SHELL_YELLOW='\033[0;33m'
SHELL_DEFAULT='\033[0m'

# install_nfs_packages() installs NFS Packages
install_nfs_packages() {

    # Install Cachefilesd
    echo "Installing cachefilesd and rpcbind..."
    echo -e "------${SHELL_DEFAULT}"
    apt-get update
    apt-get install -y cachefilesd rpcbind nfs-kernel-server tree
    echo "RUN=yes" >> /etc/default/cachefilesd
    systemctl disable cachefilesd
    systemctl disable nfs-kernel-server
    systemctl disable nfs-idmapd.service
    echo -e -n "${SHELL_YELLOW}------"
    echo "DONE"

}

# install_build_dependencies() installs the dependencies to required to build the kernel
install_build_dependencies() {

    echo -e "${SHELL_YELLOW}"
    echo "Installing build dependencies..."
    echo -e "------${SHELL_DEFAULT}"
    apt-get update
    apt-get upgrade -y
    apt-get install   kernel-wedge linux-cloud-tools-common libtirpc-dev gawk zstd ncurses-dev xz-utils bc git fakeroot make gcc pkg-config libncurses-dev libncurses-dev \
                      flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf dwarves build-essential libevent-dev libsqlite3-dev \
                      libblkid-dev libkeyutils-dev libdevmapper-dev libcap-dev default-jdk -y
    echo -e -n "${SHELL_YELLOW}------ "
    echo "DONE"

}

# download_nfs-utils() downloads version 2.5.3 of nfs-utils
download_nfs-utils() {

    # Make directory for nfs-utils
    echo -n "Creating directory for nfs-utils source... "
    mkdir -p ~/nfs-utils
    echo "DONE"
    echo -e "${SHELL_YELLOW}"
    echo "Downloading nfs-utils..."
    echo -e "------${SHELL_DEFAULT}"
    cd ~/nfs-utils
    curl -o ~/nfs-utils/nfs-utils-2.5.3.tar.gz https://mirrors.edge.kernel.org/pub/linux/utils/nfs-utils/2.5.3/nfs-utils-2.5.3.tar.gz
    tar xvf ~/nfs-utils/nfs-utils-2.5.3.tar.gz
    echo -e -n "${SHELL_YELLOW}------"
    echo "DONE"

}

# build_install_nfs-utils() builds and installs nfs-utils
build_install_nfs-utils() {

    # Make directory for nfs-utils
    echo -n "Creating directory for nfs-utils source... "
    mkdir -p ~/nfs-utils
    echo "DONE"

    echo -e "${SHELL_YELLOW}"
    echo "Downloading nfs-utils..."
    echo -e "------${SHELL_DEFAULT}"
    cd ~/nfs-utils/nfs-utils-2.5.3
    ./configure --prefix=/usr --sysconfdir=/etc --sbindir=/sbin --disable-gss
    make -j20
    make install -j20
    chmod u+w,go+r /sbin/mount.nfs
    chown nobody.nogroup /var/lib/nfs
    echo -e -n "${SHELL_YELLOW}------"
    echo "DONE"

}

# install_stackdriver_agent() installs the Stackdriver Agent for metrics
install_stackdriver_agent() {

    echo -e "${SHELL_YELLOW}"
    echo "Installing Stackdriver Agent dependencies..."
    echo -e "------${SHELL_DEFAULT}"
    curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh
    bash add-monitoring-agent-repo.sh
    apt-get update
    sudo apt-get install -y stackdriver-agent
    systemctl disable stackdriver-agent
    echo -e -n "${SHELL_YELLOW}------ "
    echo "DONE"

}

# install_golang() installs golang
install_golang() {

    echo "Installing golang...."
    echo -e "------${SHELL_DEFAULT}"
    cd ~
    curl -o go1.17.3.linux-amd64.tar.gz https://dl.google.com/go/go1.17.3.linux-amd64.tar.gz
    rm -rf /usr/local/go && tar -C /usr/local -xzf go1.17.3.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo -e -n "${SHELL_YELLOW}------ "
    echo "DONE"

}

# install_knfsd_agent() installs the knfsd-agent (see https://github.com/GoogleCloudPlatform/knfsd-cache-utils/tree/main/image/knfsd-agent)
install_knfsd_agent() {

    echo "Installing knfsd-agent...."
    echo -e "------${SHELL_DEFAULT}"
    cd /root/knfsd-agent/src
    go build -o /usr/local/bin/knfsd-agent *.go
    cp /root/knfsd-agent/knfsd-logrotate.conf /etc/logrotate.d/
    cp /root/knfsd-agent/knfsd-agent.service /etc/systemd/system/
    echo -e -n "${SHELL_YELLOW}------ "
    echo "DONE"

}


add_additional_disk () {
   
    echo Formating additional disk 
    echo -e "------${SHELL_DEFAULT}"
    mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard  /dev/disk/by-id/google-custom-kernel
    echo "Creating mounting directory"
    mkdir -p /mnt/kernel-build
    echo "Mount additional disk"
    mount -o discard,defaults  /dev/disk/by-id/google-custom-kernel /mnt/kernel-build
    echo -e -n "${SHELL_YELLOW}------ "
    echo "DONE"
}

# download_kernel() downloads the 5.13.0 Kernel
download_kernel() {

    echo "Downloading kernel source files..."
    echo -e "------${SHELL_DEFAULT}"
    cd /mnt/kernel-build/
    git clone -b Ubuntu-hwe-5.13-5.13.0-23.23_20.04.1 --depth 1 git://kernel.ubuntu.com/ubuntu/ubuntu-focal.git
    cd ubuntu-focal/
    echo -e -n "${SHELL_YELLOW}------ "
    echo "DONE"

}

# install_kernel() installs the 5.13.0 kernel
install_kernel() {

    # Install the new kernel using dpkg
    echo "Installing kernel...."
    echo -e "------${SHELL_DEFAULT}"
    LANG=C fakeroot debian/rules clean
    LANG=C fakeroot debian/rules binary
    cd ..
    dpkg -i *.deb
    echo -e -n "${SHELL_YELLOW}------ "
    echo "DONE"

}

# Prep Server
add_additional_disk
install_nfs_packages
install_build_dependencies
download_nfs-utils
build_install_nfs-utils
install_stackdriver_agent
install_golang
install_knfsd_agent
download_kernel
install_kernel

echo
echo
echo "SUCCESS: Please reboot for new kernel to take effect"
echo -e "${SHELL_DEFAULT}"
