#!/bin/bash

read -p 'What is your desired amount of Openshift users? ' user
read -p 'What would you like to name your OAuth? ' oauth

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

while true; do
    read -p "Do you wish to create admin for users? " yn
    case $yn in
        [Yy]* ) oc adm policy add-cluster-role-to-user admin user1
        htpasswd -B -b users.htpasswd user1 admin
        echo "user1 is now an admin with password: 'openshift'"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Do you wish to create userspaces for users? " yn
    case $yn in
        [Yy]* ) 
for ((j=1; j<=$user; j++))
do
    cat << EOF | oc apply -f -
    apiVersion: v1
    kind: Namespace
    metadata:
      labels:
        openshift.io/cluster-monitoring: "true"
      name: user${j}
    spec: {}
EOF
done

for ((h=1; h<=$user; h++))
do
    cat << EOF | oc apply -f -
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: admin
      namespace: user${h}
    subjects:
    - kind: User
      name: user${h}
      apiGroup: rbac.authorization.k8s.io
    roleRef:
      kind: ClusterRole
      name: admin
      apiGroup: rbac.authorization.k8s.io
EOF
done; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done