Evil Maid CHKDSK
===============
This is a simple 512-byte MBR program that pretends to be Windows CHKDSK. It asks the user for a password, writes that password back to the media it booted from, clears the bootable flag for that media, and reboots.

**NOTE**: Windows helpfully prompts the user to format the drive when it's inserted, or when they first log in after the password has been captured. I don't think this can be considered a serious tool until that's fixed, but I've used literally every byte of the MBR - the next stable version probably won't be 512 bytes :)

Terminal capture of using it with QEMU: http://ascii.io/a/1201

Video demonstration on a Windows laptop: https://www.youtube.com/watch?v=tull5_Ctz8M

To assemble
----------
`nasm -f bin bootloader.asm -o bootme`

To install on a disk
------------------
`dd if=./bootme of=/dev/<device>`

To extract the saved password
------------------
`dd if=/dev/<device> count=1 bs=512 > dump.hex ; xxd dump.hex`


Easy peasy.

Compatibility
------------
I've tested this under QEMU with floppies and IDE hard disks, on an Atom (32-bit) netbook using an SD card, and a Core i5 (64-bit) laptop using an SD card.

DISCLAIMER
----------
I haven't tested this in a large number of devices. If the fourth byte of the MBR of another disk in your system is 0x99, you're going to have a bad time (overwritten partition table and/or bootloader). This value is arbitrary and might be changed if I find a better one.
