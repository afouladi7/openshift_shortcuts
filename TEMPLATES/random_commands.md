Login to the internal registry.

`podman login -u $(oc whoami) -p $(oc whoami -t) $(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}{"\n"}')`

Getting the pull secert.

`oc get secret pull-secret -n openshift-config -o yaml | grep .dockerconfigjson: | cut -c 22- > temp.yaml; base64 --decode -i temp.yaml > pull_secret.yaml; rm temp.yaml`

Get the Cluster ID.

`oc -n openshift-machine-api -o jsonpath='{.metadata.labels.machine\.openshift\.io/cluster-api-cluster}{"\n"}' get machineset/<MachineSets_Name>`

Merge Secrets.

`jq -c --argjson var "$(jq .auths $HOME/ocp_pullsecret.json)" '.auths += $var' $HOME/ocp_pullsecret.json > merged_pullsecret.json`

Get all Operators lists from oc-mirror.

`for i in $(oc-mirror list operators --catalogs --version=4.12 | grep registry); do $(oc-mirror list operators --catalog=$i --version=4.12 > $(echo $i | cut -b 27- | rev | cut -b 7- | rev).txt); done`
