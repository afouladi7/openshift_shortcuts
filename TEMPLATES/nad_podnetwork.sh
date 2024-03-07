#!/bin/bash

PROJECT=$(oc project -q)
  cat << EOF | oc apply -f -
  apiVersion: k8s.cni.cncf.io/v1
  kind: NetworkAttachmentDefinition
  metadata:
    name: labnet
    namespace: ${PROJECT}
  spec:
    config: |
      {
              "name": "physnet",
              "topology":"localnet",
              "netAttachDefName": "${PROJECT}/labnet",
              "type": "ovn-k8s-cni-overlay",
              "cniVersion": "0.4.0"
      }
EOF
