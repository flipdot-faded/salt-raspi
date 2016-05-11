#!/bin/bash
# Downloads the latest Raspbian lite image and writes it onto a sdcard

# SD Card options
sd_guesses=(/dev/mmcblk0 /dev/mmcblk1)

# Zipped image file options
zip_dest='/tmp/raspbian-lite-latest.zip'
zip_dir='/tmp/raspbian-lite-latest'

# URLs for downloading and checking hashes
url_download='https://downloads.raspberrypi.org/raspbian_lite_latest'
url_hashes='https://www.raspberrypi.org/downloads/raspbian/'

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
cyan='\033[0;36m'
nc='\033[0m' # no color

ok="[ ${green}OK${nc} ]"
noy="[ ${yellow}NO${nc} ]"
err="[ ${red}ERROR${nc} ]"
info="[ ${cyan}INFO${nc} ]"


print_usage() {
    echo "Usage:"
    echo "$(basename $0) [SD-CARD-BLOCKDEV] [RASPBIAN-ZIPPED-IMAGE-FILE-DESTINATION]"
    echo
}

# Format bytes human readable
fmth() {
    numfmt --to=iec-i --suffix=B $1
}


echo "Checking for Raspbian image file..."
if [[ $# -ge 2 ]]; then
    zip_dest="$2"
fi
echo -e "  ${info} Using ${cyan}${zip_dest}${nc} as raspbian zipped image file."

# Download if file not present
if [[ ! -f "$zip_dest" ]]; then
    echo -e "  ${info} Image not present. Downloading newest..."
    curl -# -L -o "$zip_dest" "$url_download"
fi

# Check file's SHA1 hash
sha1_hashes=$(curl -s "$url_hashes" | grep SHA | sed -r 's/.*<strong>([a-z0-9]+)<\/strong>.*/\1/g')
sha1_hash=$(sha1sum "$zip_dest" | awk '{print $1}')
sha1_check=0
for i in ${sha1_hashes[@]}; do
    if [[ "$sha1_hash" == "$i" ]]; then
        sha1_check=1
    fi
done
if [[ ! $sha1_check ]]; then
    echo -e "  ${err} Image verification failed. No valid checksum found."
fi
echo -e "  ${ok} Image successfully verified."

# Unpack zip file
# (Seriously? Why not simply unpacked?)
if [[ -d "$zip_dir" ]]; then
    echo -e "  ${info} Archive seems to already be unzipped. Skipping..."
else
    echo -e "  ${info} Unzipping image file..."
    unzip "$zip_dest" -d "$zip_dir"
fi
img_file=$(ls "$zip_dir"/*.img | head -1)
if [[ -z "$img_file" ]]; then
    echo -e "  ${err} Could not find an image file in extracted zip file."
    exit 1
fi

sd_minsize=$(stat -c %s "$img_file")

echo -e "\nChecking for block devices..."
if [[ $# -lt 1 ]]; then
    for i in ${sd_guesses[@]}; do
        sd_size=$(lsblk -nblpdo SIZE "$i" 2>/dev/null)
        # Check block size
        if [[ $sd_size =~ ^-?[0-9]+$ ]]; then
            sd_path="$i"
            break;
        fi
    done
    # Check block device
    if [[ ! -b "$sd_path" ]]; then
        echo -e "  ${err} No valid block device found. Try setting it explicitly."
        echo
        print_usage
        exit 1
    fi
else
    sd_path="$1"
    # Check block device
    if [[ ! -b "$sd_path" ]]; then
        echo -e "  ${err} ${cyan}${sd_path}${nc} is not a block device."
        echo
        print_usage
        exit 1
    fi
    sd_size=$(lsblk -nblpdo SIZE "$sd_path")
fi

echo -e "  ${ok} ${cyan}${sd_path}${nc} chosen as block device."

# Check minimum size
if [[ $sd_size -lt $sd_minsize ]]; then
    echo -e "  ${err} SD card is too small. Need at least $(fmth ${sd_minsize}) and only has $(fmth ${sd_size})"
    exit 1
fi
echo -e "  ${ok} SD card satisfies minimum size requirements of $(fmth ${sd_minsize})."


# Confirm overwriting dialog
echo -e "\nConfirm writing to SD card..."
echo -e "  ${info} Block device:   ${sd_path} ($(fmth ${sd_size}))"
echo -e "  ${info} Image file:     ${img_file} ($(fmth ${sd_minsize}))"
echo -en "\n            Start overwriting SD card? (${green}y${nc}/${red}N${nc}) ${cyan}"

read overwrite
echo -e "${nc}"

if [[ "$overwrite" != "y" ]]; then
    echo -e "  ${err} Not writing to disk. Aborting..."
    exit 1
fi

# Actual overwriting
echo -e "  ${info} Overwriting SD card..."
#dd if="$zip_dest" | pv -s "$sd_size" | sudo dd bs=4M of="$sd_path"
pv "$img_file" | (sudo dd of="$sd_path" &>/dev/null)
if [[ $? -gt 0 ]]; then
echo -e "  ${err} Something went wrong overwriting the SD card."
fi
echo -e "  ${ok} SD card successfully overwritten. :)"
