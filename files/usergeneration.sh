#!/bin/bash

###########################
## This is for creating  ##
## users in OCP.         ##
##                       ##
## Author: Allen Fouladi ##
###########################

declare user=100
declare oauth=users

htpasswd -B -b users.htpasswd clusteradmin openshift > /dev/null

for ((i=1; i<=$user; i++))
do
if [ ! -f users.htpasswd ];then
    htpasswd -c -B -b users.htpasswd user$i openshift
else
    htpasswd -B -b users.htpasswd user$i openshift
fi
done

oc adm policy add-cluster-role-to-user cluster-admin clusteradmin > /dev/null
oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config

cat << EOF | oc apply -f -
apiVersion: config.openshift.io/v1
kind: OAuth 
metadata:
  name: cluster
spec:
  identityProviders:
  - name: ${oauth}
    mappingMethod: claim 
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret 
EOF