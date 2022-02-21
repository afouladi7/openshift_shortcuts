Login to the internal registry.

`podman login -u $(oc whoami) -p $(oc whoami -t) $(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}{"\n"}')`

Getting the pull secert.

`oc get secret pull-secret -n openshift-config -o yaml | grep .dockerconfigjson: | cut -c 22- > temp.yaml; base64 --decode -i temp.yaml > pull_secret.yaml; rm temp.yaml`

Get the Cluster ID

`oc -n openshift-machine-api -o jsonpath='{.metadata.labels.machine\.openshift\.io/cluster-api-cluster}{"\n"}' get machineset/<MachineSets_Name>`

Merge Sercets

`jq -c --argjson var "$(jq .auths $HOME/ocp_pullsecret.json)" '.auths += $var' $HOME/ocp_pullsecret.json > merged_pullsecret.json`
