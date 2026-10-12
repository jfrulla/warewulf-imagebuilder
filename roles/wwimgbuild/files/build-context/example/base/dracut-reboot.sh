#!/bin/bash

echo "This node has triggered the dracut emergency hook. Rebooting."
sleep 2
reboot -f
