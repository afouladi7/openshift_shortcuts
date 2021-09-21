#!/bin/bash

###########################
## This is for a AWS     ##
## installation of OCP.  ##
##                       ##
## Author: Allen Fouladi ##
###########################


if [ ! -f pull.txt ]
then
	echo "Please enter your pull secret from cloud.redhat.com/openshift/install in a file called pull.txt"; exit
fi

key=""

read -p "Please enter your sshkey public key: (if blank will assume to use id_rsa.pub in .ssh folder): " key

if [ -z "$key" ]
then
	key=$(<~/.ssh/id_rsa.pub)
fi

pull=$(<pull.txt)

cat << EOF > ./install-config.yaml
apiVersion: v1
baseDomain: allenfouladi.com
compute:
- architecture: amd64
  hyperthreading: Enabled 
  name: worker
  platform:
    aws:
      zones:
      - us-east-1a
      - us-east-1b
      - us-east-1c
      rootVolume:
        iops: 2000
        size: 500
        type: io1 
      type: m5a.4xlarge
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled 
  name: master
  platform:
    aws:
      zones:
      - us-east-1a
      - us-east-1b
      - us-east-1c
      rootVolume:
        iops: 2000
        size: 500
        type: io1 
      type: m5a.2xlarge
  replicas: 3
metadata:
  creationTimestamp: null
  name: testcluster
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  aws:
    region: us-east-1
publish: External
pullSecret: '$pull'
sshKey: |
  $key
EOF
