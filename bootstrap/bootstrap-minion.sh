#!/bin/bash
# bootstrap-minion.sh
# Sets up a salt minion raspberry pi
# by installing salt and setting up unused host name
#
# Inspired by:
# https://github.com/freifunkks/salt-conf/blob/master/bootstrap/bootstrap-minion.sh

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


# Make sure script is run as root
if [[ $EUID -ne 0 ]]; then
	echo "Please run this script as root" 1>&2
	exit 1
fi


# Change working directory to script's
cd "$(dirname "$0")"

echo "Bootstrapping minion..."
echo


# Check system packages
declare -a pkg_req=(salt-minion python-pip git)

# echo -n "Updating repositories... "
# [[ $(apt-get update 1>/dev/null 2> >(wc -l)) -gt 0 ]] && (echo -e "\n  ${err} Error updating repositories..." 1>&2; exit 3)
# echo -e "\n"

echo "Checking installed system packages..."
for p in ${pkg_req[@]}; do
	echo -n "  "
	if [[ $(dpkg-query -W $p 2>/dev/null) ]]; then
		echo -ne "${ok}"
	else
		echo -ne "${noy}"
		pkg_new+=($p)
	fi
	echo " $p"
done
echo

if [[ ${#pkg_new[@]} -gt 0 ]]; then
	echo -n "Installing required system packages... "
	apt-get install -y ${pkg_new[@]} &>/dev/null || (echo -e "\n  ${err} Error installing required packages" 1>&2; exit 4)
	echo -e "\n"
fi


# Check python modules
declare -a py_req=(shyaml shyxaml)

echo "Checking installed python modules..."
for p in ${py_req[@]}; do
	echo -n "  "
	if [[ $(pip show ${p}) ]]; then
		echo -ne "${ok}"
	else
		echo -ne "${noy}"
		py_new+=($p)
	fi
	echo " $p"
done
echo

if [[ ${#py_new[@]} -gt 0 ]]; then
    echo "Installing required python modules... "
    for n in ${py_new[@]}; do
        [[ `pip search "$n"` ]] || (echo -e "  ${err} $n not found"; exit 5)
        echo "Continueing nontheless..."
        piplog=$(pip2 install "$n")
        [[ $? -eq 0 ]] && echo -e "  ${ok} Success" || (echo -e "  ${err} Error"; echo "$piplog"; exit 6)
	    echo
    done
fi


# Use masterless local minion mode if not already set
echo "Configuring salt..."

minion_file=/etc/salt/minion
minion_local="file_client: local"
grep "${minion_local}" ${minion_file} &>/dev/null && echo -e "  ${ok} Local minion mode already enabled" || ( sed -i "/#file_client: remote/a ${minion_local}" ${minion_file}; echo -e "  ${ok} Enabled local minion mode" )
echo


# Clone salt-conf repo
repo_name="salt-raspi"
cd /root
[[ -d ${repo_name} ]] || (echo "Getting 'Raspberry Pi' salt configuration via git..."; git clone -q https://github.com/flipdot/${repo_name}.git ; echo)
[[ -d /srv ]] || mkdir /srv
[[ -L /srv/salt ]] || ln -s "/root/$repo_name/state" /srv/salt
[[ -L /srv/pillar ]] || ln -s "/root/$repo_name/pillar" /srv/pillar


