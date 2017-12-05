#!/bin/bash

echo -e "BASE ${LDAP_BASE}\nURI ${LDAP_SERVER}" > /etc/nslcd.conf
echo -e "binddn $ADMIN_DN\nbindpw $ADMIN_DN_PASS" >> /etc/nslcd.conf

for item in passwd shadow group; do
    sed -i "s/^${item}:.*/${item}: ldap compat /g" /etc/nsswitch.conf
done
#    sed -i "s/^Port 22/Port 2222/g" /etc/ssh/sshd_config


# ssh public key access config
if [[ $(grep -c "AuthorizedKeysCommand " /etc/ssh/sshd_config ) -eq 0 ]]; then   
  echo "AuthorizedKeysCommand /usr/local/bin/ldap_auth.sh" >> /etc/ssh/sshd_config
fi
if [[ $(grep -c "AuthorizedKeysCommandUser " /etc/ssh/sshd_config ) -eq 0 ]]; then
  echo "AuthorizedKeysCommandUser nobody" >> /etc/ssh/sshd_config
fi
if [[ $(grep -c "AuthorizedKeysFile /dev/null" /etc/ssh/sshd_config ) -eq 0 ]]; then
  echo "AuthorizedKeysFile /dev/null" >> /etc/ssh/sshd_config
fi

if /usr/sbin/nslcd ; then
  echo "run nslcd"
fi
#/usr/sbin/rsyslogd
if /usr/sbin/sshd -D ; then
  echo "run sshd"
fi
