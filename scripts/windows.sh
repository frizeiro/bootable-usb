#!/bin/bash

iso_volume=""

function nl {
    echo ""
}

function show_info {
    nl
    echo -e "\033[1;33m$@\033[0m"
}

function show_confirmation {
    nl
    read -p "$@ " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting script..."
        [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
    fi
}

function before_all {
    show_info "Before we start, let's say some points:"
    echo "- You need to have a Windows ISO file."
    echo "- You need an erasable USB device."
    echo "- We will install Homebrew and brew wimlib if it is not already installed."
    echo ""
    echo "You can download ISO here:"
    echo "Windows 10: https://www.microsoft.com/software-download/windows10ISO"
    echo "Windows 11: https://www.microsoft.com/software-download/windows11"

    show_confirmation "Let's go? (y/n)"

    install_wimlib
}

function install_wimlib {
    which -s brew
    if [[ $? != 0 ]]; then
        echo "Installing Homebrew..."

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
        if [ $? -eq 0 ]; then echo 'OK'; else echo 'NG'; fi

        if [[ $(uname -p) == 'arm' ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            export PATH=/opt/homebrew/bin:$PATH
        fi
    fi

    nl
    echo "Installing Wimlib..."
    brew install wimlib &>/dev/null
    echo "Done."

    mount_iso
}

function split_file {
    echo "Splitting install.swm..."
    wimlib-imagex split $iso_volume/sources/install.wim /Volumes/WININSTALL/sources/install.swm 3800
    echo "Done."

    unmount_disks
}

function copy_files {
    echo "Copying files..."
    rsync -avh --progress --exclude=sources/install.wim $iso_volume/ /Volumes/WININSTALL
    echo "Done."

    split_file
}

function format_usb {
    show_info "Selecting USB device..."
    show_confirmation "Is it your USB device connected?. (y/n)"

    show_info 'Choose the USB destination device.'
    echo 'Listing all available external physical devices:'
    nl

    diskutil list external physical

    show_info 'Enter the destination USB name. E.g. /dev/disk4'
    read -e path

    show_confirmation "The \"$path\" device will be formatted and all data will be lost. Are you sure? (y/n)"
    nl

    echo "Formatting \"$path\"..."
    diskutil eraseDisk MS-DOS "WININSTALL" MBR $path
    echo "Done."

    copy_files
}

function mount_iso {
    show_info 'Enter the downloaded ISO path:'
    read -e path

    nl
    echo "Mouting ISO file..."
    iso_volume=$(hdiutil mount $path | sed -E 's|(.+)/Volume|/Volume|g')
    echo "Mounted on $iso_volume."

    format_usb
}

function unmount_disks {
    nl
    echo "Unmounting disks..."
    diskutil unmount $iso_volume
    diskutil unmount /Volumes/WININSTALL
    echo "Done."

    show_info "That's it!"
}

before_all
