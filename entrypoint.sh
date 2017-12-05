#!/bin/bash

echo -e "BASE ${LDAP_BASE}\nURI ${LDAP_SERVER}" > /etc/nslcd.conf

for item in passwd shadow group; do
    sed -i "s/^${item}:.*/${item}: ldap compat /g" /etc/nsswitch.conf
done
#    sed -i "s/^Port 22/Port 2222/g" /etc/ssh/sshd_config


# ssh public key access config
echo "AuthorizedKeysCommand /usr/local/bin/ldap_auth.sh" >> /etc/ssh/sshd_config
echo "AuthorizedKeysCommandUser root" >> /etc/ssh/sshd_config

if /usr/sbin/nslcd ; then
  echo "run nslcd"
fi
#/usr/sbin/rsyslogd
if /usr/sbin/sshd -d ; then
  echo "run sshd"
fi
