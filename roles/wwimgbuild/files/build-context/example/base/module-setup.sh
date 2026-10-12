#!/bin/bash

# This function tells Dracut that our module should always be included
check() {
    return 0
}

# No additional module dependencies
depends() {
    return 0
}

# This function installs our emergency reboot script into the initramfs
install() {
    # $moddir is the path to this module's directory (/usr/lib/dracut/modules.d/99dracut-reboot)
    inst_hook emergency 99 "$moddir/dracut-reboot.sh"
}
