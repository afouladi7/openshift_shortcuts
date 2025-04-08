Login to the internal registry.

`podman login -u $(oc whoami) -p $(oc whoami -t) $(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}{"\n"}')`

Getting the pull secert.

`oc get secret pull-secret -n openshift-config -o yaml | grep .dockerconfigjson: | cut -c 22- > temp.yaml; base64 --decode -i temp.yaml > pull_secret.yaml; rm temp.yaml`

Get the Cluster ID.

`oc -n openshift-machine-api -o jsonpath='{.metadata.labels.machine\.openshift\.io/cluster-api-cluster}{"\n"}' get machineset/<MachineSets_Name>`

Merge Secrets.

`jq -c --argjson var "$(jq .auths $HOME/ocp_pullsecret.json)" '.auths += $var' $HOME/ocp_pullsecret.json > merged_pullsecret.json`

Get all Operators lists from oc-mirror.

`for i in $(oc-mirror list operators --catalogs --version=4.17 | grep registry); do $(oc-mirror list operators --catalog=$i --version=4.17 > $(echo $i | cut -b 27- | rev | cut -b 7- | rev).txt); done`

Cron Job for oc-mirror to pull daily

```
SHELL=/bin/bash

0 12 * * * source /allen/ocp-sno/env.sh; /allen/ocp-sno/bin/oc-mirror --config /allen/ocp-sno/imageset.yaml docker://registry.<domain>.com:5000 --ignore-history; dir=$(tail /allen/.oc-mirror.log | grep UpdateService | awk {'print$5'}); export KUBECONFIG=/allen/kubeconfig; /allen/ocp-sno/bin/oc apply -f $dir
```

OpenShift Audit to see who did whatever to VMs

```
{ log_type="audit" } | json | objectRef_resource ="virtualmachines", verb != "get", verb != "watch", verb != "patch", verb != "list", user_username !~ "system:serviceaccount:.*" | line_format `{{ if eq .verb "create" }} create {{ else if eq .verb "delete" }} delete {{else}} {{ .objectRef_subresource }} {{end}} {{ .objectRef_name }} ({{ .objectRef_namespace  }}) by {{ .user_username  }}`
```


To approve all pending CSRs, run the following command:

`$ oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve`


Export KUBECONFIG from the node

`export KUBECONFIG=$(find /etc -name *localhost.kubeconfig)`


Shutdown cluster

`oc -n openshift-kube-apiserver-operator get secret kube-apiserver-to-kubelet-signer -o jsonpath='{.metadata.annotations.auth\.openshift\.io/certificate-not-after}'`
`for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do oc debug node/${node} -- chroot /host shutdown -h 1; done`
