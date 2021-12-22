# Custom ESXi for vLAB running on Intel NUC


## ESXi Customize script usage
### Build ISO image

```bash

```

### Upgrade with offline package

#### Create offline package

Start a Powershell session with admin privileges

```bash
Set-ExecutionPolicy RemoteSigned
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\ESXi-Customizer-PS.ps1 -v70 -pkgDir .\ -ozip
```

> Change `-v70` by required version

Available versions are listed in [this page](https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml)


#### Upgrade ESXi software

It is assuming you have a VMFS configured to point to a NFS server to access /vmfs/volumes/nfs-storage-applications/vmware/ESXi\ Customize/

```bash
# Update package (and not install to not override custom VIB)
esxcli software profile update \
    -d /vmfs/volumes/nfs-storage-applications/vmware/ESXi\ Customize/ESXi-7.0U2d-18538813-standard-customized.zip \
    -p ESXi-7.0U2d-18538813-standard-customized

# Reboot server to apply
reboot
```

> Don't forget to update both filename and package name

### Install USB NIC package

USB drivers are maintained by [vmware flings](https://flings.vmware.com/) and can be downloaded directly from [here](https://flings.vmware.com/usb-network-native-driver-for-esxi)

```bash
esxcli software vib install \
    -d /vmfs/volumes/nfs-storage-applications/vmware/ESXi\ Customize/ESXi702-VMKUSB-NIC-FLING-47140841-component-18150468.zip
```

Script example to reconfigure vswitch when usb interface comes up:

```bash
vusb0_status=$(esxcli network nic get -n vusb0 | grep 'Link Status' | awk '{print $NF}')
count=0
while [[ $count -lt 20 && "${vusb0_status}" != "Up" ]]
do
    sleep 10
    count=$(( $count + 1 ))
    vusb0_status=$(esxcli network nic get -n vusb0 | grep 'Link Status' | awk '{print $NF}')
done

if [ "${vusb0_status}" = "Up" ]; then
    esxcfg-vswitch -L vusb0 vSwitch0
    esxcfg-vswitch -M vusb0 -p "Management Network" vSwitch0
    esxcfg-vswitch -M vusb0 -p "VM Network" vSwitch0
fi
```

## Resources

- [ESXi on Intel Lake Frost Canyon](https://www.virten.net/2020/03/esxi-on-10th-gen-intel-nuc-comet-lake-frost-canyon/)
- `ESXi-Customizer-PS` by [VMWARE](https://www.v-front.de/p/esxi-customizer-ps.html)
- [ESXi Patch tracker](https://esxi-patches.v-front.de/)
- [Home Lab HW](https://blog.labvl.net/homelab/homelab-p1/) (racking, cabling, components)
