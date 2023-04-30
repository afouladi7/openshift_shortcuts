#!/bin/bash

#This script will double check all essential containers are mirrored for disconnected bare OCP

#auth file will need to be in ~/.docker/config.json
#this is expecting a https connection, if you do not have a crt or key for your registry add "--dest-tls-verify=false" in the skopeo command

read -p "What release of OCP do you want? (i.e 4.12.10 or 4.12.11 or latest) " release
read -p "Mirror address/location? Please include port# " mirror

echo "This is only mirroring the containers for " $release

wget -q https://mirror.openshift.com/pub/openshift-v7/clients/ocp/$release/release.txt

for i in $(cat release.txt | grep ocp-v4.0-art-dev | awk '{print$2}')
do
	skopeo copy docker://$i docker://$mirror/openshift/release
done

for i in $(cat release.txt | grep ocp-release | awk '{print$3}')
do
	skopeo copy docker://$i docker://$mirror/openshift/release-images
done
