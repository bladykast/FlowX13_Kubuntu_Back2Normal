#!/bin/bash
# Starting over script for Kubuntu 21.04?, ROG Flow X13 GV301QE
# Tom Bladykas, 10-21-2021

##### Functions #####

getLatest () {
# Gets latest release of project from .git link, extracts, and throws you in the folder
# Thanks to https://julienrenaux.fr/2013/10/04/how-to-automatically-checkout-the-latest-tag-of-a-git-repository/
git clone $1
directory=$(basename -s .git $1)
cd $directory
git fetch origin
git fetch --tags
latestTag=$(git describe --tags `git rev-list --tags --max-count=1`)
git -c advice.detachedHead=false checkout $latestTag
}

installBuild () {
# For fprintd and libprintf, both meson and ninja are used to build from source and install
meson builddir
ninja -C builddir install
{

boldEcho () {
# Bolds print output for visibility
echo -e "\\033[1m> $1 <\033[0m"
}

updateUpgrade () {
# Good ol' commands, here for no particular reason
apt update
apt upgrade -y
}

##### End of Functions #####


# Must not prefix with sudo when calling script
if [[ $(id -u) == 0 ]]; then
    echo 'You cannot call this script using sudo. Aborting.'
    exit 99
fi

# Make temporary directory
tempdir=$(mktemp -d)
cd $tempdir

# Get current user, for deescalation
currentuser=$(whoami)


##### Beginning of dependency fetch ######

# Call for Escalation

#

boldEcho 'Checking for (and installing) updates...'
updateUpgrade

# boldEcho 'Installing acpi_call for custom fan control...'
# apt install -y acpi-call
# touch /etc/modules-load.d/acpi-call.conf
# echo "acpi_call" | tee -a /etc/modules-load.d/acpi-call.conf

boldEcho 'Installing asusctl dependencies...'
apt install -y libclang-dev libudev-dev cargo

boldEcho 'Installing supergfxctl dependencies...'
apt install -y curl git build-essential

boldEcho 'Installing libprintf and fprintd dependencies...'
apt purge --auto-remove fprintd libfprint-2-2
apt install -y python3-venv python3-pip git gettext valgrind libpam-fprintd
pip3 install --no-input meson libglib2.0-dev libgusb-dev libgrepository1.0-dev gtk-doc-tools libpolkit-gobject-1-dev libsystemd-dev libpam0g-dev libpam-wrapper libfprint-2-dev python3-pypamtest libxml2-utils libdbus-1-dev ninja gobject python-dbusmock

## De-escalate things ##

##### Un-escalated things  #####
cd $tempdir

boldEcho 'Fetching Rustup...' # Required for supergfxctl
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs
source ~/.bash_profile
source ~/.profile
source ~/.cargo/env
cd $tempdir

boldEcho 'Fetching asusctl...'
getLatest https://gitlab.com/asus-linux/asusctl.git

boldEcho 'Building asusctl...'
make
cd $tempdir

boldEcho 'Fetching supergfxctl...'
getLatest https://gitlab.com/asus-linux/supergfxctl.git

boldEcho 'Building supergfxctl...'
make
cd $tempdir

boldEcho 'Fetching libprinf...'
getLatest https://gitlab.freedesktop.org/libfprint/libfprint.git

boldEcho 'Building & installing libprintf...'
installBuild
cd $tempdir

boldEcho 'Fetching fprintd...'
getLatest https://gitlab.freedesktop.org/libfprint/fprintd.git

boldEcho 'Building & installing fprintd...'
installBuild
cd $tempdir


##### Escalated, again?? #####

boldEcho 'Installing asusctl...'
cd $tempdir/asusctl/
make install

boldEcho 'Starting asusd service...'
systemctl enable asusd
systemctl start asusd

boldEcho 'Installing supergfxctl...'
cd $tempdir/supergfxctl/
make install

boldEcho 'Starting supergfxd service...'
systemctl enable supergfxd.service
systemctl start supergfxd.service

##### Cleanup #####
boldEcho 'Done! Would you like to remove the build directories?'
rm -rf $tempdir # Risky!

##### De-escalate, again... #####

boldEcho 'Would you like to enable asusctl desktop notifications? (KDE/Gnome)'

# This *can't* be run as root
boldEcho 'Enabling notifications for KDE/GNOME...'
systemctl --user enable asus-notify.service
systemctl --user start asus-notify.service


