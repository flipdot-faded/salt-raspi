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

apt_log="/tmp/apt.log"


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

 echo -n "Updating repositories... "
 [[ $(apt-get update 1>/dev/null 2> >(wc -l)) -gt 0 ]] && (echo -e "\n  ${err} Error updating repositories..." 1>&2; exit 3)
 echo -e "\n"

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

apt_log_lines_old=$(cat "${apt_log}" | wc -l)
if [[ ${#pkg_new[@]} -gt 0 ]]; then
    echo -n "Installing required system packages... "
    if [[ ! $(apt-get install -y ${pkg_new[@]} >> "${apt_log}") ]]; then
       echo "'apt-get install -y ${pkg_new[@]}' exited with status code $?" >> "${apt_log}"
       echo -e "\n  ${err} Error installing required packages" 1>&2
       apt_log_lines_new=$(cat "${apt_log}" | wc -l)
       tail -n+$((apt_log_lines_new-apt_log_lines_old)) "${apt_log}"
       exit 4
    fi
    echo -e "\n"
fi


# Check python modules
declare -a py_req=(shyaml)

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
        if [[ $(pip search "$n" | wc -l) -lt 1 ]]; then
           echo -e "  ${err} $n not found"
           exit 5
        fi
        piplog=$(pip install "$n" &>1)
        if [[ $? -eq 0 ]]; then
            echo -e "  ${ok} Success"
        else
            echo -e "  ${err} Error"
            echo "${piplog}"
            exit 6
        fi
        echo
    done
fi


# Use masterless local minion mode if not already set
echo "Configuring salt..."

minion_file=/etc/salt/minion
minion_local="file_client: local"
grep "${minion_local}" ${minion_file} &>/dev/null && echo -e "  ${ok} Local minion mode already enabled" || ( sed -i "/#file_client: remote/a ${minion_local}" ${minion_file}; echo -e "  ${ok} Enabled local minion mode" )

# Clone salt-raspi repo
gh_user="flipdot"
gh_repo="salt-raspi"
cd /root
if [[ -d ${gh_repo} ]]; then
    echo -e "  ${ok} ${gh_repo} already cloned"
else
    git clone -q https://github.com/${gh_user}/${gh_repo}.git 2>/dev/null && echo -e "  ${ok} ${gh_repo} successfully cloned" || echo -e "  ${err} ${gh_repo} could not be cloned"
    echo
fi
[[ -d /srv ]] && echo -e "  ${ok} /src already existent" || (mkdir /srv; echo -e "  ${ok} /src successfully created")
[[ -L /srv/salt ]] && echo -e "  ${ok} /srv/salt already existent" || (ln -s "/root/${gh_repo}/state" /srv/salt; echo -e "  ${ok} /srv/salt successfully linked")
[[ -L /srv/pillar ]] && echo -e "  ${ok} /srv/pillar already existent" || (ln -s "/root/${gh_repo}/pillar" /srv/pillar; echo -e "  ${ok} /srv/pillar successfully linked")
echo


echo "Setting up minion..."

minion_file="${gh_repo}/pillar/minions.sls"
domain="fd"
minion_root="minions"
minion_list=($(cat "${minion_file}" | shyaml keys ${minion_root}))

# TODO: unfuck this!?

function choose_hostname() {
    echo "  Choose available hostname:"

    i=1
    for l in ${minion_list[@]}; do
        echo -e "   ${cyan}$i${nc}: $l"
        ((i++))
    done
    echo

    echo -ne "    Hostname: ${cyan}"
    read minion_id
    ((minion_id--))
    echo -e "${nc}"

    # Check if hostname is already in use

    h="${minion_list[$minion_id]}.${domain}"
    s="${h} has address "
    ip_dns=$(host ${h} | grep "${s}" | sed "s/${s}//")
    [[ $ip_dns = "" ]] && ip_dns="${red}NOT FOUND${nc}"
    ips=($(hostname -I))

    minion_yaml="${minion_pre}${minion_list[$minion_id]}.sls"
    # shyaml get-value minions.tv\\.fd.ip

    if [[ ${minion_id} =~ ^-?[0-9]+$ && ${minion_id} -lt ${#minion_list[@]} && $minion_id -ge 0 ]]; then
        minion_name=${minion_list[${minion_id}]}
        minion_name_escaped=$(echo "${minion_name}" | sed 's/\./\\./g')

        # Check if the IP resolved via DNS is contained within the set of local IPs
        #if [[ $(cat ${minion_file} | shyaml get-value ${minion_root}.${minion_name_escaped}) == "True" ]]; then
        #  | shyaml get-value minions.tv\\.fd.ip

        ip_salt=$(cat ${minion_file} | shyaml get-value ${minion_root}.${minion_name_escaped}.ip)
        [[ $ip_salt = "" ]] && ip_salt="${red}NOT FOUND${nc}"

        if [[ $ip_dns == *"${ips}"* && $ip_salt == *"${ips}"* ]]; then
            #if [[ ! $(ping -W 2 -c1 ${minion_list[$minion_id]}.${domain} ) ]]; then
            echo -e "    ${ok} ${minion_list[$minion_id]} chosen without conflicts"
            return $minion_id
        else
            echo -e "    ${err} ${minion_list[$minion_id]} has the wrong IP address"
            echo "              now:  ${ips}"
            #for k in ${ips[@]}; do
            #    echo $k
            #done
            echo -e "              dns:  ${ip_dns}"
            echo -e "              salt: ${ip_salt}"
            echo
            echo -ne "              Choose anyways? (${green}y${nc}/${red}N${nc}) ${cyan}"
            read override
            echo -e "${nc}"

            if [[ "$override" == "y" ]]; then
                return $minion_id
            fi
            choose_hostname
        fi
    else
        echo -e "    ${err} Your input was not valid\n"
        choose_hostname
    fi
}

choose_hostname
hostname=${minion_list[$?]}

# Change hostname in running session
sysctl kernel.hostname="${hostname}" &>/dev/null
# Make the change permanent
echo ${hostname} > /etc/hostname

# Salt's first run
echo -e "\nSalt is taking over now...\n"
salt-call state.highstate 2>/dev/null

# Reload new hostname in newly opened shell
exec ${SHELL}
