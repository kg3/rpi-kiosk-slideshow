# RPi Kiosk Slideshow a.k.a RPi Digital Signage

*WIP*

[ Google Drive ] + [ Linux Systemd ] + [ Chromium kiosk ] = A raspberry Pi that's always showing fresh slides a.k.a digital signage

# The How

After authenticating with [Google Drive](https://github.com/odeke-em/drive); rpi-kiosk-slideshow will download images from the specified folder.

For each image added in the google drive folder, an [ImageMagick](https://www.imagemagick.org/Usage/) script is run to output multiple widths, by default 1080 & 720. For fitting comfortably with different screen sizes.

With the images from the google drive folder, rpi-kiosk-slideshow will generate an html/js local website that uses [jquery-backstretch](https://github.com/jquery-backstretch/jquery-backstretch) for it smartly chooses an appropriate image based on the screen size.

A systemd service runs chromium-kiosk mode that points to the custom built slideshow.

A cronjob regularly (default 4 hours) regenerates the slideshow.html with the new images and refreshes the kiosk

For stabilities sake, the system is slimmed down and extra updates are performed. If there's any problems the slideshow will stop runnning and the desktop image will change to tell you an error message. Which you can fix via putting in a maintanence file on the google drive folder.

# Install

`bash install-kiosk-slideshow.sh` or `chmod +x install-kiosk-slideshow.sh; ./install-kiosk-slideshow.sh`

This script will remove all of Raspian's learning environment and extra software for faster updating. Including the home folders, just to keep the system clean. This script was written with the idea that this system will only be used for displaying a slideshow and nothing else so extra folders are removed as well. I suggest reading the script before running it blindly.

This install script and other files will be placed in the home directory. Keep them there after the install so if in the future there is problems they can be used from a maintanence file placed in the google-drive shared folder.

## First connect to the wifi

    TODO: auto-connect from a file on google drive with wifi/pass.

## Authenticate with Google Drive

Specify the folder to use inside the `kiosk.conf` file

# Using

After the install plugging the pi into hdmi on a t.v should work fine if you reboot and see the slideshow start with your images appearing.

If things aren't setup correctly try manually adding a file in the home directory. `touch ~/notify_pi_needs_attention` to do manual work on the pi without the kiosk running.


# Work In Progress

TODOs

- `kiosk.conf` pre-specify google drive share folder

- `maintanence` place a file like this in the google drive and it will tell the install script to reset default settings and try a different wifi password

- `wifi-auto` place this file with wifi-name and password on separate lines for the rpi to auto connect onto this wifi

- `desktop-notify` for issues stop the slideshow and write a message on the desktop with debug info. Restore image after a reboot.
