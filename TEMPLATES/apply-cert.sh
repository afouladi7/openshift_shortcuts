#!/bin/bash

### manually CA=./allen.redhat.com.CA
KEY=./allen.redhat.com.key
CERT_WITH_CHAIN=./allen.redhat.com.crt.fullchain
REPLACE=true

echo "Update the variables and the resource names... or press Ctrl-C to abort"
read


[[ ${REPLACE} == "true" ]] && echo Removing previous certificates
#### [[ ${REPLACE} == "true" ]] && oc delete configmap redhat-trusted-ca-list -n openshift-config
[[ ${REPLACE} == "true" ]] && oc delete secret redhat-ingress-certificate -n openshift-ingress
[[ ${REPLACE} == "true" ]] && oc delete secret redhat-api-certificate -n openshift-config


#echo "Uploading new certificate's Certificate Authority (CA)..."
#oc create configmap redhat-trusted-ca-list \
#  --from-file=ca-bundle.crt=${CA} -n openshift-config
#
#echo "Rolling out new trusted CA list to all nodes (full cluster reboot initiated!"
#oc patch proxy/cluster --type=merge -p '{"spec":{"trustedCA":{"name":"redhat-trusted-ca-list"}}}'



echo "Uploading new Ingress certificate..."
oc create secret tls redhat-ingress-certificate \
  --cert=${CERT_WITH_CHAIN} --key=${KEY} -n openshift-ingress

echo "Applying new Ingress certificate..."
oc patch ingresscontroller.operator/default --type=merge \
  -p '{"spec":{"defaultCertificate": {"name": "redhat-ingress-certificate"}}}' -n openshift-ingress-operator



echo "Uploading new API certificate..."
oc create secret tls redhat-api-certificate \
  --cert=${CERT_WITH_CHAIN} --key=${KEY} -n openshift-config

echo "Applying new API certificate..."
oc patch apiserver/cluster --type=merge \
  -p '{"spec":{"servingCerts": {"namedCertificates": [{"names": ["api.allen.dota-lab.iad.redhat.com"], "servingCertificate": {"name": "redhat-api-certificate"}}]}}}'

echo "All done, just wait for the nodes to reboot and new pods to roll out..."
