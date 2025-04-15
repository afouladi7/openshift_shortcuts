ssh core@163.254.2.9

# lspci -nn | grep NVIDIA
05:00.0 3D controller [0302]: NVIDIA Corporation TU104GL [Tesla T4] [10de:1eb8] (rev a1)


# lspci -nnks 05:00.0
05:00.0 3D controller [0302]: NVIDIA Corporation TU104GL [Tesla T4] [10de:1eb8] (rev a1)
	Subsystem: NVIDIA Corporation Device [10de:12a2]
	Kernel driver in use: vfio-pci  ### This appears when it's configured correctly
	Kernel modules: nouveau

----------------------------

# 0. Target the "master" role because this is a Single Node of OpenShift (SNO)
# 1. Add "intel_iommu=on" or "amd_iommu=on" to the kernel command line
# 2. Tell vfio-pci to claim your devices in vfio-pci-devices.conf
# 3. Load the vfio-pci module via load-vfio-pci.conf

---
variant: openshift
version: 4.16.0
metadata:
  name: 100-gpu-passthrough-to-vm
  labels:
    machineconfiguration.openshift.io/role: master

openshift:
  kernel_arguments:
    #- amd_iommu=on
    - intel_iommu=on

storage:
  files:
  - path: /etc/modules-load.d/load-vfio-pci.conf 
    mode: 0644
    overwrite: true
    contents:
      inline: vfio-pci

  - path: /etc/modprobe.d/vfio-pci-devices.conf
    mode: 0644
    overwrite: true
    contents:
      inline: |
        options vfio-pci ids=10de:1eb8,10de:2235
        # You can specify multiple card types as a comma-separated value to ids=
        # NVIDIA TU104GL [Tesla T4] == 10de:1eb8
        # NVIDIA GA102GL [A40]      == 10de:2235


------------

curl -O https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane

chmod a+x ./butane

./butane --version
Butane 0.21.0

./butane gpu-passthrough-to-vm.bu -o gpu-passthrough-to-vm.yaml

oc create -f gpu-passthrough-to-vm.yaml
