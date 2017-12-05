#!/bin/bash
cn=$1

ldapsearch -h ldap -D "$ADMIN_DN" -w $ADMIN_DN_PASS -x -b "$BASE_DN" "(&(objectclass=posixAccount)(cn=user01))" | sed -n '/^ /{H;d};/sshPublicKey:/x;$g;s/\n *//g;s/sshPublicKey: //gp'
