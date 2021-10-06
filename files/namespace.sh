#!/bin/bash

###########################
## This is for creating  ##
## namespaces in OCP.    ##
##                       ##
## Author: Allen Fouladi ##
###########################

while true; do
    read -p "Do you wish to create mulitple namespace? " yn
    case $yn in
        [Yy]* )
read -p "How many namespaces would you like to create? " user
for ((j=1; j<=$user; j++))
do
read -p "What should you like to name you single namespace? " ns
    cat << EOF | oc apply -f -
    apiVersion: v1
    kind: Namespace
    metadata:
      labels:
        openshift.io/cluster-monitoring: "true"
      name: ${ns}
    spec: {}
EOF
done; break;;
        [Nn]* ) read -p "What should you like to name you single namespace? " ns
        oc create ns $ns; break;;
        * ) echo "Please answer yes or no.";;
    esac
done