# salt-raspi
A collection of [Minibian](https://minibianpi.wordpress.com/about/) [salt](https://docs.saltstack.com/en/latest/topics/installation/debian.html) configurations and helper scripts.

## Write Raspbian lite image to SD card
Use the included utility script `write-image.sh`.

## Setup new Raspberry
After successfully writing the image to an SD card, insert it into the Raspberry Pi and start it. Now connect to it via SSH with the default credentials (user: `pi` / password: `raspberry`). First of all make sure that you expand the file system by invoking `sudo raspi-config` and choosing `Expand Filesystem`. After a neccessary reboot, make a full system upgrade like so: `sudo apt-get update && sudo apt-get upgrade -y`. At the end you install git with `sudo apt-get install git` and clone this very repo by using `git clone "https://github.com/flipdot/salt-raspi.git"`. Now `cd` into the `bootstrap` directory and call `sudo bootstrap-minion.sh`.
Later, you can update salt by using `sudo salt-call state.highstate 2>/dev/null`
