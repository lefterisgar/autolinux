#!/bin/bash
# AutoLinux - The ultimate customization and maintenance tool for Linux

# shellcheck disable=SC1090

readonly autolinux_version='0.0.0'
readonly autolinux_date='01-01-1970'

readonly autolinux_branding=' _______                   _       _
(_______)        _        (_)     (_)
 _______ _   _ _| |_ ___   _       _ ____  _   _ _   _
|  ___  | | | (_   _/ _ \ | |     | |  _ \| | | ( \ / )
| |   | | |_| | | || |_| || |_____| | | | | |_| |) X (
|_|   |_|____/   \__\___/ |_______|_|_| |_|____/(_/ \_)

The ultimate customization and maintenance tool for Linux.'

readonly pkgdesc_bluez='The official Linux Bluetooth protocol stack. DO NOT remove it if you use Bluetooth.'
readonly pkgdesc_cups='The printing system. DO NOT remove it if you have a printer.'
readonly pkgdesc_fedoraCore_misc='Error reporting, Firefox bookmarks, LVM support, a useless live USB creation utility and RAM compression. Who needs those?'
readonly pkgdesc_fedoraKDE_misc='Redundant package manager, Input Method selection framework & D-Bus Debugger. Not needed by a regular user.'
readonly pkgdesc_firefox='Customizing Firefox via policies.json can improve its privacy, security, and performance by restricting or configuring features like telemetry, cookies, and network protocols'
readonly pkgdesc_flatpak='Framework for distributing Linux applications. DO NOT disable if you don'\''t know what you are doing.'
readonly pkgdesc_ibus='Input method framework, mostly for people who speak Chinese, Japanese, and Korean (among others). Only integrates well with Gnome and it'\''s not required if you don'\''t speak these languages.'
readonly pkgdesc_kde_akonadi='Backend for Kmail and many other KDE office applications (Akregator, Kontact, Korganizer, etc.). Has a reputation for slowing down the system. Also, the alternatives for e.g. Kmail are much better, rendering Akonadi both useless and redundant.'
readonly pkgdesc_kde_games='Fun games from KDE. Safe to remove.'
readonly pkgdesc_kde_kwallet='Password management tool. Removing it may break some applications that rely on it.'
readonly pkgdesc_kde_multimedia1='Multimedia from KDE (Part 1). Includes a multimedia player, a music player, a camera application and paint. Useful for most users.'
readonly pkgdesc_kde_multimedia2='Multimedia from KDE (Part 2). Includes KDE'\''s image viewer and document viewer. Useful for most users.'
readonly pkgdesc_kde_tools1='Tools from KDE (Part 1). IRC, RDC and VNC clients & software used to improve the accessibility of the desktop (e.g. magnifier). None of which a regular user would likely ever need.'
readonly pkgdesc_kde_tools2='Tools by KDE (Part 2). File archiver, calculator, text editor and screenshot capture utility. Useful for most users.'
readonly pkgdesc_libreoffice='Office productivity suite. Useful for most users.'
readonly pkgdesc_libreoffice_draw='All-purpose diagramming and charting tool. Only useful if you draw graphics or diagrams.'
readonly pkgdesc_libreoffice_math='Equation editor. Only useful if you do math on your computer'

# Functions for printing colored symbols to the console
printCross() {
    printf -- '[\e[1;31m✗\e[0m] \e[1;31m%b\e[0m\n' "${*}"
}

printError() {
    printCross "⚠ $1"
    printf -- '    Error code: %s\n    For more information, please check the documentation.\n' "$2"
}

printInfo() {
    printf -- '[\e[1;93mi\e[0m] %b\n' "${*}"
}

printNewline() { printf '\n'; }

printTick() {
    printf -- '[\e[1;32m✓\e[0m] \e[1;32m%b\e[0m\n' "${*}"
}

printWelcomeDialog() {
    # Clear the console
    clear

    printf -- '%s\n\nAbout this script:
---> Version      : %s
---> Release date : %s
---> Author       : Lefteris Garyfalakis

System Information:
---> Distribution : %s
---> Session type : %s

Please note that a [Y/n] prompt means that '\''Yes'\'' is the default choice, while [y/N] is the opposite.
Pressing the ENTER key selects the default option in either case.

Please select how do you want to proceed:
[1] Post-installation setup
[2] Maintenance & cleanup' "$autolinux_branding" "$autolinux_version" "$autolinux_date" "$1" "$XDG_SESSION_TYPE"

    read -n 1 -rs

    printf '\n\n'
}

askQuestion() {
    printf -- '\e[0m[\e[1;94m?\e[0m] %b ' "${*}"
    read -n 1 -r

    printNewline
}

dnfRemovePrompt() {
    printInfo 'Preparing to remove the following:'
    printf -- '    Package(s)  : %s\n    Description : %s\n' "$1" "$2"

    askQuestion 'Is this ok? [Y/n]'

    if [[ $REPLY =~ ^[Yy]$|^$ ]]; then
        # shellcheck disable=SC2086
        dnf remove -y $1 >/dev/null 2>&1
        printTick 'Successfully removed:' "$1"
    fi

    printNewline
}

dnfUpdate() {
    askQuestion 'Perform a system update? [Y/n]'

    if [[ $REPLY =~ ^[Yy]$|^$ ]]; then
        # Force an immediate update of the repository lists
        printInfo 'Updating system! Please wait...'
        dnf update -y --refresh > /dev/null 2>&1

        # Remove orphaned packages
        printInfo 'Removing orphaned packages...'
        dnf autoremove -qy

        # Print a success message once DNF has finished
        printTick 'Successfully updated the system!'
    fi
}

fwUpdate() {
    printInfo 'Updating system firmware! Please wait...'

    fwupdmgr update -y > /dev/null 2>&1
}

hardware_NVIDIA_GPU() {
    printInfo 'Detecting GPU...'

    if lspci | grep -i nvidia > /dev/null; then
        printInfo 'Your system appears to have an NVIDIA GPU. Installing the proprietary NVIDIA drivers can offer better performance, compatibility, and additional features.'

        askQuestion 'Do you want to proceed? [Y/n]'

        printNewline
        return 0
    else
        printTick 'No NVIDIA GPU found!\n'
        return 1
    fi
}

hardware_touchpad() {
    printInfo 'Detecting touchpad...'

    if libinput list-devices | grep -i touchpad > /dev/null; then
        printTick 'Touchpad detected!'
        printInfo 'Making sure to not disable any related service...'

        isTouchpadPresent=1
    else
        printTick 'No touchpad detected!\n'

        isTouchpadPresent=0
    fi

    # Export the result so we can access it later, from a regular user
    export isTouchpadPresent
}

hardware_trim() {
    printInfo 'Trimming all supported drives! Please wait...'
    fstrim -a
    printTick 'Trim completed!\n'
}

postInstall_firefox() {
    printInfo "$pkgdesc_firefox"

    askQuestion 'Do you want to continue? [Y/n]'

    if [[ $REPLY =~ ^[Yy]$|^$ ]]; then
        printInfo 'Tweaking Firefox in progress...'

        printInfo 'Enforcing policies via policies.json. Please wait...'
        cp "$parent_path"/data/firefox/policies.json /usr/lib64/firefox/distribution/policies.json

        printInfo 'Applying preferences via firefox.js. Please wait...'
        cp "$parent_path"/data/firefox/firefox.js /usr/lib64/firefox/defaults/pref/firefox.js

        printTick 'Changes have been applied successfully!\n'
    fi
}

# Runs across all Fedora spins
postinstall_FedoraCore() {
    # Perform DNF optimizations
    printInfo 'Optimizing DNF...'

    # Set a few default values
    max_parallel_downloads=3
    fastestmirror=false

    # Override these values by loading the config
    source <(grep max_parallel_downloads < /etc/dnf/dnf.conf)
    source <(grep fastestmirror < /etc/dnf/dnf.conf)

    # Set max_parallel_downloads to 10
    if [[ $max_parallel_downloads -lt 10 ]]; then
        printInfo "max_parallel_downloads is $max_parallel_downloads. Setting it to 10..."
        dnf config-manager --setopt=max_parallel_downloads=10 --save
        printTick 'max_parallel_downloads set to 10.'
    else printTick "max_parallel_downloads is $max_parallel_downloads."
    fi

    # Set fastestmirror to true
    if [[ $fastestmirror == false ]]; then
        printInfo 'fastestmirror is disabled. Enabling it...'
        dnf config-manager --setopt=fastestmirror=true --save
        printTick 'fastestmirror enabled.\n'
    else printTick 'fastestmirror is enabled.\n'
    fi

    # Detect if the system has a touchpad
    hardware_touchpad

    # Detect if the system has an NVIDIA GPU
    hardware_NVIDIA_GPU

    # If the system has an NVIDIA GPU and the user has agreed to install the drivers
    if [[ $? == 0 && $REPLY =~ ^[Yy]$|^$ ]]; then
        # Enable RPMFusion without asking
        postinstall_RPMFusion

        # Install the drivers quietly
        dnf install akmod-nvidia nvidia-vaapi-driver > /dev/null 2>&1

        printTick 'NVIDIA drivers have been installed successfully!'
    # If those conditions were not met (i.e. RPMFusion was not enabled)
    else
        # Ask the user if he wants to enable it
        askQuestion 'Enable RPM Fusion (Free & Nonfree)? [Y/n]'

        # If the answer is yes, enable it
        if [[ $REPLY =~ ^[Yy]$|^$ ]]; then postinstall_RPMFusion; fi
    fi

    printNewline

    # If the user has enabled RPMFusion
    if dnf repolist | grep rpmfusion >/dev/null; then
        # Ask him if he wants to enable hardware accelerated codecs
        askQuestion 'Install hardware accelerated codecs? [Y/n]'

        if [[ $REPLY =~ ^[Yy]$|^$ ]]; then
            # https://rpmfusion.org/Howto/Multimedia
            printInfo 'Installing multimedia libraries...'
            dnf groupupdate multimedia -y --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin > /dev/null 2>&1

            printInfo 'Installing Intel(R) media driver...'
            dnf install -y intel-media-driver > /dev/null 2>&1

            printInfo 'Installing AMD hardware codecs...'
            dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld > /dev/null 2>&1
            dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld > /dev/null 2>&1

            printTick 'Codecs have been installed successfully!'
        fi

        printNewline
    fi

    askQuestion 'Install Microsoft TrueType fonts? [y/N]'

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        printInfo 'Installing dependencies...'
        dnf install -y cabextract xorg-x11-font-utils > /dev/null 2>&1

        printInfo 'Installing Microsoft TrueType fonts...'
        dnf install -y \
        https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm > /dev/null 2>&1

        printTick 'Fonts have been installed successfully!'
    fi

    printNewline

    postInstall_firefox

    # Disable a handful of systemd services to decrease the boot time
    printInfo 'Disabling unnecessary system services...'

    systemctl mask avahi-daemon.service gssproxy.service NetworkManager-wait-online.service systemd-oomd.service sys-kernel-debug.mount sys-kernel-tracing.mount > /dev/null 2>&1

    printTick 'Done!\n'

    printInfo 'Removing unnecessary software: STAGE 1 (Fedora core)'

    # Remove various useless applications present on all official Fedora spins (including official)
    dnfRemovePrompt 'abrt audit fedora-bookmarks jfsutils lvm2 mediawriter ModemManager zram-generator' "$pkgdesc_fedoraCore_misc"

    # Ask the user if he wants to remove LibreOffice
    dnfRemovePrompt 'libreoffice-core' "$pkgdesc_libreoffice"

    # If he doesn't, suggest removing two useless core LibreOffice applications
    if ! [[ $REPLY =~ ^[Yy]$|^$ ]]; then
        dnfRemovePrompt 'libreoffice-math' "$pkgdesc_libreoffice_math"
        dnfRemovePrompt 'libreoffice-draw' "$pkgdesc_libreoffice_draw"
    fi

    # A few more suggestions for extreme debloaters
    dnfRemovePrompt 'ibus' "$pkgdesc_ibus"
    dnfRemovePrompt 'flatpak' "$pkgdesc_flatpak"
    dnfRemovePrompt 'bluez' "$pkgdesc_bluez"
    dnfRemovePrompt 'cups' "$pkgdesc_cups"
}

postinstall_FedoraKDE() {
    printInfo 'Removing unnecessary software: STAGE 2 (KDE Spin)'

    # Remove various useless applications that only come with the Fedora KDE spin
    dnfRemovePrompt 'dnfdragora imsettings qt5-qdbusviewer' "$pkgdesc_fedoraKDE_misc"

    # Remove KDE games
    dnfRemovePrompt 'kmahjongg kmines kpat' "$pkgdesc_kde_games"

    # De-akonadization
    dnfRemovePrompt '*akonadi*' "$pkgdesc_kde_akonadi"

    # Remove most preinstalled KDE tools
    dnfRemovePrompt 'konversation krdc krfb kcharselect kfind kmag kmousetool kmouth plasma-welcome' "$pkgdesc_kde_tools1"
    dnfRemovePrompt 'ark kcalc kdeconnectd kwrite spectacle' "$pkgdesc_kde_tools2"

    # Remove most preinstalled KDE multimedia applications
    dnfRemovePrompt 'dragon elisa-player kamoso kolourpaint' "$pkgdesc_kde_multimedia1"
    dnfRemovePrompt 'gwenview okular' "$pkgdesc_kde_multimedia2"

    dnfRemovePrompt 'kwalletmanager5' "$pkgdesc_kde_kwallet"

    if [[ $REPLY =~ ^[Yy]$|^$ ]]; then export disableKwallet=true; fi

    # Accounts-daemon is not safe to disable on Gnome
    systemctl mask accounts-daemon.service > /dev/null 2>&1

    postinstall_KDE_autologin

    su "$SUDO_USER" -c postinstall_KDE
}

postinstall_KDE() {
    printInfo 'Applying KDE-specific tweaks to improve your experience!'

    # Add CTRL+Alt+T shortcut for opening Konsole
    kwriteconfig5 --file kglobalshortcutsrc --group org.kde.konsole.desktop --key _k_friendly_name "Konsole"
    kwriteconfig5 --file kglobalshortcutsrc --group org.kde.konsole.desktop --key _launch "Ctrl+Alt+T,Ctrl+Alt+T,Konsole"
    printTick 'Added CTRL+Alt+T as a shortcut for launching Konsole.'

    # Disable logout confirmation
    kwriteconfig5 --file ksmserverrc --group General --key confirmLogout --type bool false
    printTick 'Disabled logout confirmation screen.'

    # Disable splash screen
    kwriteconfig5 --file ksplashrc --group KSplash --key Engine none
    kwriteconfig5 --file ksplashrc --group KSplash --key Theme None
    printTick 'Disabled splash screen.'

    # Disable top left corner activity
    kwriteconfig5 --file kwinrc --group Effect-windowview --key BorderActivateAll 9
    kwriteconfig5 --file kwinrc --group ElectricBorders --key TopLeft --delete
    printTick 'Disabled top left corner activity.\n'

    # Disable trash confirmation
    kwriteconfig5 --file kiorc --group Confirmations --key ConfirmTrash --type bool false

    # Do not remember opened tabs in Dolphin
    kwriteconfig5 --file dolphinrc --group General --key ConfirmClosingMultipleTabs --type bool false
    kwriteconfig5 --file dolphinrc --group General --key RememberOpenedTabs --type bool false

    # Show permanent delete button
    kwriteconfig5 --file kdeglobals --group KDE --key ShowDeleteCommand --type bool true

    # Automount USB flash drives
    askQuestion 'Automount USB flash drives? [y/N]'

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kwriteconfig5 --file kded_device_automounterrc --group General --key AutomountEnabled --type bool true
        kwriteconfig5 --file kded_device_automounterrc --group General --key AutomountOnLogin --type bool true
        kwriteconfig5 --file kded_device_automounterrc --group General --key AutomountUnknownDevices --type bool true
        printTick 'USB drives will be automounted.'
    fi

    printNewline

    # Disable lockscreen
    askQuestion 'Disable the lockscreen? [Y/n]'

    if [[ $REPLY =~ ^[Yy]$|^$ ]]; then
        kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock --type bool false
        kwriteconfig5 --file kscreenlockerrc --group Daemon --key LockOnResume --type bool false
        printTick 'Lockscreen has been disabled!.'
    fi

    printNewline

    # If there is a touchpad, then tweak some touchpad-related settings
    if [[ $isTouchpadPresent -eq 1 ]]; then
        kwriteconfig5 --file kcm_touchpadrc --group Touchpad --key TapButton1 true
        printTick 'Enabled tap-to-click.\n'
    # Otherwise, disable the service entirely
    else
        kwriteconfig5 --file kded5rc --group Module-kded_touchpad --key autoload --type bool false
        printTick 'Disabled the touchpad service.\n'
    fi

    if [[ $disableKwallet ]]; then
        kwriteconfig5 --file kwalletrc --group Wallet --key Enabled --type bool false
        printTick 'Disabled KWallet.\n'
    fi

    # Disable unnecessary KDE services
    kwriteconfig5 --file kded5rc --group Module-kded_accounts --key autoload --type bool false
    kwriteconfig5 --file kded5rc --group Module-kded_bolt --key autoload --type bool false
    kwriteconfig5 --file kded5rc --group Module-kwrited --key autoload --type bool false
    kwriteconfig5 --file kded5rc --group Module-plasmavault --key autoload --type bool false
    kwriteconfig5 --file kded5rc --group Module-proxyscout --key autoload --type bool false
    kwriteconfig5 --file kded5rc --group Module-remotenotifier --key autoload --type bool false
    kwriteconfig5 --file kded5rc --group Module-smbwatcher --key autoload --type bool false
    printTick 'Disabled unnecessary KDE services.\n'
}

postinstall_KDE_autologin() {
    askQuestion 'Enable automatic login? [y/N]'

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        truncate -s0 /etc/sddm.conf

        kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Autologin --key Relogin --type bool false
        kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Autologin --key Session plasma
        kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Autologin --key User "$SUDO_USER"

        kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Theme --key Current breeze

        kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Users --key MaximumUid 60000
        kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Users --key MinimumUid 1000

        printTick 'Automatic login has been enabled!'
    fi
}

postinstall_RPMFusion() {
    # If RPM Fusion is not enabled
    if ! dnf repolist | grep rpmfusion >/dev/null; then
        # Enable RPM Fusion Free repository
        printInfo 'Enabling RPM Fusion Free repository...'
        dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-"$VERSION_ID".noarch.rpm > /dev/null

        printTick 'Enabled!'

        # Enable RPM Fusion Non-Free repository
        printInfo 'Enabling RPM Fusion Non-Free repository...'
        dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$VERSION_ID".noarch.rpm > /dev/null

        printTick 'Enabled!'
    else printTick 'RPMFusion already enabled!'
    fi
}

# Check if the script is running as root and if not, then rerun
if [[ $EUID -ne 0 ]];
then
    exec sudo -E /bin/bash "$0" "$@"
fi

# Find parent path
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" || exit ; pwd -P )

# Export functions that need to be run from a local user
export -f askQuestion printInfo printNewline printTick postinstall_KDE

# Load OS identification data
source /etc/os-release

# If the distro is Ubuntu
if [[ $ID == 'ubuntu' ]]; then
    # Fetch the flavor from the installation log
    distroID=$(< /var/log/installer/media-info head -n1 | awk '{print $1;}')

    # Welcome the user
    printWelcomeDialog "${distroID} ${VERSION_ID}"
elif [[ $ID == 'fedora' ]]; then
    # Welcome the user
    printWelcomeDialog "$PRETTY_NAME"

    if [[ $REPLY == '1' ]]; then
        # Commands that are common for all Fedora spins (including official)
        postinstall_FedoraCore

        # Spin-specific tweaks
        if [[ $VARIANT_ID == 'kde' ]]; then postinstall_FedoraKDE; fi

        # Update the system afterwards
        dnfUpdate

        # Update the system firmware
        fwUpdate

        # Trim all supported devices
        hardware_trim
    fi
else printError 'Distro couldn'\''t be detected or unsupported!' '1000'
fi
