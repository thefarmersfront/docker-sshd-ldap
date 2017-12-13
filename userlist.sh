#!/bin/bash

DIALOG="dialog"
MENU_LIST=$(mktemp /tmp/menu.list.XXX)
SERVER_LIST=$(mktemp /tmp/server.XXX)

trap ctrl_c INT
trap ctrl_c SIGINT
trap ctrl_c SIGTERM

function ctrl_c() {
    logger -t [BASTION] -i -p authpriv.info catch the user Break
    exit
}

userid=$(id | awk '{print $1}' | awk -F\( '{print $2}' | sed -e s/\)//g)

user_search=$(ldapsearch -h ldap -D "ADMIN_DN " -w ADMIN_DN_PASS -x -b "LDAP_BASE" "(&(gidNumber=*)(uid=$userid))" gidNumber | grep gidNumber: | awk '{print $2}')

group_name=$(ldapsearch -h ldap -D "ADMIN_DN " -w ADMIN_DN_PASS -x -b "ou=group,LDAP_BASE" "(&(gidNumber=$user_search))" cn | grep cn: | awk '{print $2}')

host_group=$(ldapsearch -h ldap -D "ADMIN_DN " -w ADMIN_DN_PASS -x -b "ou=host,LDAP_BASE" "(&(cn=$group_name))" memberNisNetgroup | grep memberNisNetgroup: | awk '{print $2}')

function get_server_list() {
    if [[ -z $host_group ]]; then
        ldapsearch -h ldap -D "ADMIN_DN " -w ADMIN_DN_PASS -x -b "ou=host,LDAP_BASE" "(&(cn=$group_name))" nisNetgroupTriple | grep nisNetgroupTriple: | awk '{print $2}' | sed -e s/\(// | sed -e s/\)// >>$SERVER_LIST
    else
        for i in $host_group; do
            ldapsearch -h ldap -D "ADMIN_DN " -w ADMIN_DN_PASS -x -b "cn=$i,ou=host,LDAP_BASE" "(&(cn=*))" nisNetgroupTriple | grep nisNetgroupTriple: | awk '{print $2}' | sed -e s/\(// | sed -e s/\)// >>$SERVER_LIST
        done
    fi
}

function get_addtional_group_list() {
    for i in $(ldapsearch -h ldap -D "ADMIN_DN " -w ADMIN_DN_PASS -x -b "ou=group,LDAP_BASE" "(&(memberUid=$userid))" cn | grep cn: | awk '{print $2}'); do
        ldapsearch -h ldap -D "ADMIN_DN " -w ADMIN_DN_PASS -x -b "ou=host,LDAP_BASE" "(&(cn=$i))" nisNetgroupTriple | grep nisNetgroupTriple: | awk '{print $2}' | sed -e s/\(// | sed -e s/\)// >>$SERVER_LIST
    done

}

function set_menu_list() {
    #	cat $SERVER_LIST | awk -F, '{print $1" "$3}' >>  $MENU_LIST
    count=0
    for i in $(cat $SERVER_LIST | awk -F, '{print $3}'); do
        host_name=$(grep -i $i $SERVER_LIST | awk -F, '{print $1}')
        if [[ $(fping -t 50 $i | grep -c "alive") -eq 1 ]]; then
            echo "$host_name Alive" >>$MENU_LIST
        else
            echo "$host_name Down" >>$MENU_LIST
        fi
        echo $count
        count=$(expr $count + $((($RANDOM % 15))))
        if [[ $count -gt "98" ]]; then
            count=99
        fi
    done
    if [[ $group_name == "admin" ]]; then
        if [[ -n "$BASTION_SERVER_IP" ]]; then
            echo "Bastion_server $BASTION_SERVER_IP" >>$MENU_LIST
        fi
    fi
    echo 100
    sleep 1
}

get_server_list
get_addtional_group_list
set_menu_list | $DIALOG --backtitle "SSH CONNECTOR" --title "Server Status Check" --gauge "Find Alive Servers..." 6 80 0

server_alive=$(grep -c Alive $MENU_LIST)
server_down=$(grep -c Down $MENU_LIST)

if [[ $(id -u) -ne 0 ]]; then
    menu=$(cat $MENU_LIST)

    if [[ ! -f /sshd_key/$userid ]]; then
        while [ -z $ssh_pass ]; do
            ssh_pass=$($DIALOG --title "Password for sshkey file" --cancel-label "Exit" \
                --clear --insecure --passwordbox "Enter your ssh-key File  Password(not ssh id password)" 20 80 3>&1 1>&2 2>&3 3>&-)
            if [[ $? -ne 0 ]]; then
                clear
                echo "Exit from User"
                exit 0

            fi

            ssh_pass_verify=$($DIALOG --title "Password for sshkey file" --cancel-label "Exit" \
                --clear --insecure --passwordbox "Enter your ssh-key File  Password Again" 20 80 3>&1 1>&2 2>&3 3>&-)
            if [[ $? -eq 0 ]]; then
                if [ $ssh_pass == $ssh_pass_verify ] && [ $ssh_pass != "" ]; then
                    if ! ssh-keygen -f /sshd_key/$userid -P $ssh_pass -q; then
                        clear
                        echo "ssh-keygen Failed"
                        exit
                    fi
                else
                    if [[ -z $ssh_pass ]]; then
                        $DIALOG --title "Password for sshkey file" --clear --msgbox "Password is empty" 20 80
                    else
                        $DIALOG --title "Password for sshkey file" --clear --msgbox "Password doesn't match" 20 80
                    fi
                    unset ssh_pass
                fi
            else
                clear
                echo "Exit from User"
                exit 0

            fi
        done
    fi

    while [ -z $connect_host ]; do

        connect_host=$($DIALOG --backtitle "SSH CONNECTOR" --cancel-label "Exit" \
            --title "SSH Server List" --clear \
            --menu "$server_alive Server is Alive. $server_down Server is Down. \n [Select Server To Connect] " 30 80 22 $menu 3>&1 1>&2 2>&3 3>&-)

        if [[ $? -eq 0 ]]; then
            clear
            if [[ $connect_host != "Bastion_server" ]]; then
                host_ip=$(grep "^$connect_host," $SERVER_LIST | awk -F, '{print $3}')
                user_id=$(grep "^$connect_host," $SERVER_LIST | awk -F, '{print $2}')
                if [[ -z $user_id ]]; then
                    user_id=$userid
                fi
                if [[ $(fping -t 50 $host_ip | grep -c "alive") -eq 1 ]]; then
                    echo "############################################"
                    echo "######### Connect to $connect_host #########"
                    echo "############################################"
                    logger -t [BASTION] -i -p authpriv.info connect to server $user_id@$host_ip
                    rm -rf $MENU_LIST $SERVER_LIST
                    ssh -q -X -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /sshd_key/$userid $user_id@$host_ip && exit
                else
                    rm -rf $MENU_LIST $SERVER_LIST
                    echo "############################################"
                    echo "#########  $connect_host is Down  ##########"
                    echo "############################################"
                    exit
                fi
                if [[ $? -ne 0 ]]; then
                    rm -rf $MENU_LIST $SERVER_LIST
                    exit
                fi
            else
                logger -t [BASTION] -i -p authpriv.info connect to server $connect_host
                rm -rf $MENU_LIST $SERVER_LIST
                echo "Have Nice Day?"
            fi
        else
            rm -rf $MENU_LIST $SERVER_LIST
            echo "Exit From User"
            exit 0
        fi
    done
fi
