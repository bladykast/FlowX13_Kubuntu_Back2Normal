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
sudo -A meson builddir
sudo -A ninja -C builddir install
}

boldEcho () {
# Bolds print output for visibility
echo -e "\\033[1m> $1 <\033[0m"
}

updateUpgrade () {
# Good ol' commands, here for no particular reason
sudo -A apt update
sudo -A apt upgrade -y
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

# Call for Escalation; cache password
touch elevate.sh
chmod +x elevate.sh
echo '#!/bin/bash' | tee elevate.sh
echo 'kdialog --password "Password required to proceed"' | tee -a elevate.sh

export SUDO_ASKPASS=$tempdir/elevate.sh

##### Beginning of dependency fetch ######

boldEcho 'Checking for (and installing) updates...'
updateUpgrade

# boldEcho 'Installing acpi_call for custom fan control...'
# sudo -A apt install -y acpi-call
# sudo -A touch /etc/modules-load.d/acpi-call.conf
# echo "acpi_call" | sudo -A tee -a /etc/modules-load.d/acpi-call.conf

boldEcho 'Installing asusctl dependencies...'
sudo -A apt install -y libclang-dev libudev-dev cargo

boldEcho 'Installing supergfxctl dependencies...'
sudo -A apt install -y curl git build-essential

boldEcho 'Installing libprintf and fprintd dependencies...'
sudo -A apt purge -y --auto-remove fprintd libfprint-2-2
sudo -A apt install -y python3-venv python3-pip git gettext valgrind libpam-fprintd
sudo -A pip3 install --no-input meson libglib2.0-dev libgusb-dev libgrepository1.0-dev gtk-doc-tools libpolkit-gobject-1-dev libsystemd-dev libpam0g-dev libpam-wrapper libfprint-2-dev python3-pypamtest libxml2-utils libdbus-1-dev ninja gobject python-dbusmock

##### Un-escalated things  #####
cd $tempdir

boldEcho 'Fetching Rustup...' # Required for supergfxctl? fix this
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs
source ~/.bash_profile
source ~/.profile
source ~/.cargo/env
cd $tempdir

boldEcho 'Fetching asusctl...'
getLatest https://gitlab.com/asus-linux/asusctl.git
asusctl_version=$latestTag

boldEcho 'Building asusctl...'
make
cd $tempdir

boldEcho 'Fetching supergfxctl...'
getLatest https://gitlab.com/asus-linux/supergfxctl.git
supergfxctl_version=$latestTag

boldEcho 'Building supergfxctl...'
make
cd $tempdir

boldEcho 'Fetching libprinf...'
getLatest https://gitlab.freedesktop.org/libfprint/libfprint.git
libprintf_version=$latestTag

boldEcho 'Building & installing libprintf...'
installBuild
cd $tempdir

boldEcho 'Fetching fprintd...'
getLatest https://gitlab.freedesktop.org/libfprint/fprintd.git
fprintd_version=$latestTag

boldEcho 'Building & installing fprintd...'
installBuild
cd $tempdir

##### Escalated, again?? #####

boldEcho 'Installing asusctl...'
cd $tempdir/asusctl/
sudo -A make install

boldEcho 'Starting asusd service...'
sudo -A systemctl enable asusd
sudo -A systemctl start asusd

boldEcho 'Installing supergfxctl...'
cd $tempdir/supergfxctl/
sudo -A make install

boldEcho 'Starting supergfxd service...'
sudo -A systemctl enable supergfxd.service
sudo -A systemctl start supergfxd.service

boldEcho 'Would you like to enable notifications for KDE/Gnome? [Y/n]'
read remove
if [[ $remove == 'n' ]]; then

    boldEcho 'To enable notifications in the future, run these: '
    echo '$ systemctl --user enable asus-notify.service'
    echo '$ systemctl --user start asus-notify.service'
    else
    systemctl --user enable asus-notify.service
    systemctl --user start asus-notify.service
    echo 'Notifications enabled.'
fi


##### Cleanup #####
boldEcho 'Done!'

boldEcho 'Program versions installed:'
echo asusctl: $asusctl_version
echo supergfxctl: $supergfxctl_version
echo libprinf: $libprintf_version
echo fprintd: $fprintd_version
echo ' '

boldEcho 'Would you like to remove the build directories? [y/N]'
read remove
if [[ $remove == 'y' ]]; then
    rm -rf $tempdir
    echo 'Build directory removed.'
    else
    echo Build files remain at $tempdir
fi

exit 0
