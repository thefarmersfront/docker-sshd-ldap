#!/bin/bash
cn=$1

ldapsearch -h $LDAP_SERVER -D $ADMIN_DN -w $ADMIN_DN_PASS -x -b $LDAP_BASE "(&(objectclass=posixAccount)(cn=$cn))" | sed -n '/^ /{H;d};/sshPublicKey:/x;$g;s/\n *//g;s/sshPublicKey: //gp'
