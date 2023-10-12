``` bash
#setup
subscription-manager register
subscription-manager auto-attach

subscription-manager repos --enable ansible-2.9-for-rhel-8-x86_64-rpms

subscription-manager repos --enable=rhel-8-server-extras-rpms
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm


yum install ansible vim wget podman traceroute httpd-tools jq httpd

systemctl start httpd.service
systemctl enable httpd.service

ansible localhost -m lineinfile -a 'path=$HOME/.bashrc regexp="^export OCP_RELEASE" line="export OCP_RELEASE=4.8.3"'
source $HOME/.bashrc

#Download the OpenShift CLI tool
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$OCP_RELEASE/openshift-client-linux-$OCP_RELEASE.tar.gz



#Extract the client and place in into the path
sudo tar xzf openshift-client-linux-$OCP_RELEASE.tar.gz -C /usr/local/sbin/ oc kubectl
#validate it works
which oc

#Setup bash completion for oc
oc completion bash | sudo tee /etc/bash_completion.d/openshift > /dev/null

#Let's make sure we can pull an image we'll be needing later and ensure we can run it
podman pull ubi8/ubi:8.4
podman run ubi8/ubi:8.4 cat /etc/os-release
#This shows the name and version we expected so we can move on with our setup

#First thing we need to do is create some directories for our container registry we will be setting up and changing the owner to our current user
sudo mkdir -p /opt/registry/{auth,certs,data}
sudo chown -R $USER /opt/registry

#Next we will create a certificate for our registry to use
cd /opt/registry/certs
openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -addext "subjectAltName = DNS:<localhost>" -out domain.crt
#Country Name (2 letter code) [XX]:US
#State or Province Name (full name) []: Colorado
#Locality Name (eg, city) [Default City]:Colorado Springs
#Organization Name (eg, company) [Default Company Ltd]:Lockheed
#Organizational Unit Name (eg, section) []:C2
#Common Name (eg, your name or your server's hostname) []:utility.dota-lab.iad.redhat.com
#Email Address []:<your-email-address>test@redhat.com

#The common name is the one that matters the rest of these can be pretty much any value but the common name must be the correct name for your machine in order for the certificate to properly resolve

#Next we will add simple password authentication on our registry we will just use the username openshift and the password redhat for demonstration purposes
htpasswd -bBc /opt/registry/auth/htpasswd openshift redhat

#Now we can setup our resgistry to run, use the password and certificate we created and automaticatlly start in case the vm ever restarts
podman run -d --name mirror-registry \
-p 5000:5000 --restart=always \
-v /opt/registry/data:/var/lib/registry:z \
-v /opt/registry/auth:/auth:z \
-e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
-e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
-v /opt/registry/certs:/certs:z \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
-e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
docker.io/library/registry:2

#Now we can try connecting to our registry server
curl -u openshift:redhat https://utility.dota-lab.iad.redhat.com:5000/v2/_catalog
#You see the certificate is not trusted, but we can temporarily ensure it works by ignoring the ceritifate verification with a '-k'
curl -u openshift:redhat -k https://utility.dota-lab.iad.redhat.com:5000/v2/_catalog
#It works so now we need to fix the turst issues by coping the certificate to the systems trust store and updating the ca trust
sudo cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
#Now we test it again and see everything works
curl -u openshift:redhat https://utility.dota-lab.iad.redhat.com:5000/v2/_catalog

#allow x509 to work properly for installation
export GODEBUG=x509ignoreCN=0

#we can even see the image is being stored in the folder we created for this purpose
ls /opt/registry/data/docker/registry/v2/repositories

#the utilityvm is now setup how we need and we can move on to the next part back on our bastion 
#We will now be ensuring the bastion can connect to our new container registry and then loading that registry with the images we will be needing
curl -u openshift:redhat https://utility.dota-lab.iad.redhat.com:5000/v2/_catalog
#Ooops we ran into the certificate trust issue again, so we need to do the same steps as before, we'll have to pull the certifacte to the bastion add it to the trust and update the ca trust
sudo scp utility.dota-lab.iad.redhat.com:/opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
#lets test again
curl -u openshift:redhat https://utility.dota-lab.iad.redhat.com:5000/v2/_catalog

#Everything is working lets work on setting up a pull secret that can be used for logging into the local registry
  podman login -u openshift -p redhat --authfile $HOME/pullsecret_config.json utility.dota-lab.iad.redhat.com:5000

#Now you will need to use your red hat developer account
#Login to cloud.redhat.com
#Click on Red Hat OpenShift Cluster Manager
#Create Cluster
#Red Hat OpenShift Container Platform
#Pick the approropriate environement for the install, which for today's demo is Red Hat OpenStack Platform
#We are doing the user-provisioned infrastructure
#Click on Copy pull secret
#Back to the terminal
#Pull-secret
{"auths":{"cloud.openshift.com":...}} > $HOME/ocp_pullsecret.json
#you can only pass one pull secret to the openshift installer so we're going to use jq to merge the two files together into a single file

podman login -u openshift -p redhat --authfile $HOME/pullsecret_config.json utility.dota-lab.iad.redhat.com:5000

jq -c --argjson var "$(jq .auths $HOME/pullsecret_config.json)" '.auths += $var' $HOME/ocp_pullsecret.json > merged_pullsecret.json
ls $HOME/merged_pullsecret.json

ansible localhost -m lineinfile -a 'path=$HOME/.bashrc regexp="^export LOCAL_REGISTRY" line="export LOCAL_REGISTRY=utility.dota-lab.iad.redhat.com:5000"'
ansible localhost -m lineinfile -a 'path=$HOME/.bashrc regexp="^export LOCAL_REPOSITORY" line="export LOCAL_REPOSITORY=ocp4/openshift4"'
ansible localhost -m lineinfile -a 'path=$HOME/.bashrc regexp="^export LOCAL_SECRET_JSON" line="export LOCAL_SECRET_JSON=/$HOME/merged_pullsecret.json"'
ansible localhost -m lineinfile -a 'path=$HOME/.bashrc regexp="^export PRODUCT_REPO" line="export PRODUCT_REPO=openshift-release-dev"'
ansible localhost -m lineinfile -a 'path=$HOME/.bashrc regexp="^export RELEASE_NAME" line="export RELEASE_NAME=ocp-release"'
ansible localhost -m lineinfile -a 'path=$HOME/.bashrc regexp="^export ARCHITECTURE" line="export ARCHITECTURE=x86_64"'
source $HOME/.bashrc

oc adm -a ${LOCAL_SECRET_JSON} release mirror \
     --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-x86_64 \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-x86_64

oc adm release extract -a $HOME/merged_pullsecret.json --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-x86_64"
oc adm release extract -a ${LOCAL_SECRET_JSON} --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}"

mv openshift-install /usr/local/sbin/openshift-install

wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/latest/rhcos-4.8.2-x86_64-vmware.x86_64.ova
cp rhcos-4.8.2-x86_64-vmware.x86_64.ova /var/www/html/


firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=5000/tcp --permanent
firewall-cmd --reload

#iptables-save | grep 80 -A IN_public_allow -p tcp -m tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT

wget utility.dota-lab.iad.redhat.com/rhcos-4.8.2-x86_64-vmware.x86_64.ova

#get registry trust cert
sudo cat /opt/registry/certs/domain.crt

#generate ssh key
ssh-keygen -t rsa -b 4096

#grab vsphere cert

curl -L -O -k https://vcenter.dota-lab.iad.redhat.com/certs/download.zip &&     unzip download.zip &&     cp certs/lin/* /etc/pki/ca-trust/source/anchors &&     update-ca-trust extract

cat /etc/pki/ca-trust/source/anchors *.0

```

```yaml
apiVersion: v1
baseDomain: dota-lab.iad.redhat.com
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    vsphere:
      cpu: 4
      coresPerSocket: 2
      memoryMB: 32768
      osDisk:
        diskSizeGB: 120
  replicas: 5
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    vsphere:
      cpus: 4
      coresPerSocket: 2
      memoryMB: 16384
      osDisk:
        diskSizeGB: 120
  replicas: 3
metadata:
  creationTimestamp: null
  name: legend
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.15.168.0/24
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  vsphere:
    apiVIP: 10.15.168.134
    cluster: Cluster
    datacenter: Datacenter
    defaultDatastore: local-nvme
    ingressVIP: 10.15.168.135
    network: VM Network
    password: <accountPassword>
    username: <account@vsphere.local>
    vCenter: vcenter.dota-lab.iad.redhat.com
    clusterOSImage: http://utility.dota-lab.iad.redhat.com/rhcos-4.8.2-x86_64-vmware.x86_64.ova
publish: External
pullSecret: '{"auths":{"cloud.openshift.com":}...}'
sshKey: |
  ssh-rsa <public key>
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  <vsphere root ca>
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  <registry root ca>
  -----END CERTIFICATE-----

imageContentSources: 
- mirrors:
    - utility.dota-lab.iad.redhat.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
    - utility.dota-lab.iad.redhat.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```


``` bash

INFO Consuming Install Config from target directory
INFO Obtaining RHCOS image file from 'http://utility.dota-lab.iad.redhat.com/rhcos-4.8.2-x86_64-vmware.x86_64.ova'
INFO The file was found in cache: /root/.cache/openshift-installer/image_cache/819aa4b038e2bebadab4fa53de5271f8. Reusing...
INFO Creating infrastructure resources...
INFO Waiting up to 20m0s for the Kubernetes API at https://api.legend.dota-lab.iad.redhat.com:6443...
INFO API v1.20.0+2817867 up
INFO Waiting up to 30m0s for bootstrapping to complete...
INFO Destroying the bootstrap resources...
INFO Waiting up to 40m0s for the cluster at https://api.legend.dota-lab.iad.redhat.com:6443 to initialize...
INFO Waiting up to 10m0s for the openshift-console route to be created...
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/root/ocp-vmware/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.legend.dota-lab.iad.redhat.com
INFO Login to the console with user: "kubeadmin", and password: "IRVWA-hXAuy-qopuQ-amDfv"
INFO Time elapsed: 26m51s




```

``` bash

govc datastore.upload -ds ISOs agent.x86_64.iso agent.x86_64.iso

govc vm.create -iso=agent.x86_64.iso -iso-datastore=ISOs -ds=rhdata6-nfs -net="airgap-VLAN999" -c=8 -m=16384 -disk=200GB -on=false -net.address=00:50:56:82:8c:dc dcds-master-0
govc vm.create -iso=agent.x86_64.iso -iso-datastore=ISOs -ds=rhdata6-nfs -net="airgap-VLAN999" -c=8 -m=16384 -disk=200GB -on=false -net.address=00:50:56:82:8c:dd dcds-master-1
govc vm.create -iso=agent.x86_64.iso -iso-datastore=ISOs -ds=rhdata6-nfs -net="airgap-VLAN999" -c=8 -m=16384 -disk=200GB -on=false -net.address=00:50:56:82:8c:de dcds-master-2

```
