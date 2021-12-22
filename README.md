# Custom ESXi for vLAB running on Intel NUC

## ESXi Customize script usage

### Get list of available version

```bash
[root@nuc01-esx02:~] esxcli software sources profile \
    list --depot=https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml | grep ESXi-7

ESXi-7.0.0-15843807-standard      VMware, Inc.  PartnerSupported  2020-03-16T10:48:54  2020-03-16T10:48:54
[...]
ESXi-7.0U1c-17325551-no-tools     VMware, Inc.  PartnerSupported  2020-12-15T12:44:20  2020-12-15T12:44:20
ESXi-7.0U2a-17867351-standard     VMware, Inc.  PartnerSupported  2021-04-29T00:00:00  2021-04-29T00:00:00
ESXi-7.0U2a-17867351-no-tools     VMware, Inc.  PartnerSupported  2021-04-29T00:00:00  2021-04-09T05:56:10
ESXi-7.0U2sc-18295176-standard    VMware, Inc.  PartnerSupported  2021-08-24T00:00:00  2021-08-24T00:00:00
ESXi-7.0U2sc-18295176-no-tools    VMware, Inc.  PartnerSupported  2021-08-24T00:00:00  2021-07-09T12:35:05
ESXi-7.0U2c-18426014-standard     VMware, Inc.  PartnerSupported  2021-08-24T00:00:00  2021-08-24T00:00:00
ESXi-7.0U2c-18426014-no-tools     VMware, Inc.  PartnerSupported  2021-08-24T00:00:00  2021-08-04T11:40:25
ESXi-7.0U2d-18538813-standard     VMware, Inc.  PartnerSupported  2021-09-14T00:00:00  2021-09-14T00:00:00
ESXi-7.0U2d-18538813-no-tools     VMware, Inc.  PartnerSupported  2021-09-14T00:00:00  2021-08-27T10:33:50
```

### Build ISO image

- Option 1:

```powershell
> Set-ExecutionPolicy RemoteSigned
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> .\ESXi-Customizer-PS-v2.6.0.ps1 -v70 -pkgDir .\
```


- Option 2:

```powershell
# (Optional) Install PowerCLI Module
Install-Module -Name VMware.PowerCLI -Scope CurrentUser

Add-EsxSoftwareDepot https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml
Add-EsxSoftwareDepot .\ESXi670-NE1000-32543355-offline_bundle-15486963.zip
New-EsxImageProfile -CloneProfile "ESXi-6.7.0-20191204001-standard" -name "ESXi-6.7.0-20191204001-NUC" -Vendor "virten.net"
Remove-EsxSoftwarePackage -ImageProfile "ESXi-6.7.0-20191204001-NUC" -SoftwarePackage "ne1000"
Add-EsxSoftwarePackage -ImageProfile "ESXi-6.7.0-20191204001-NUC" -SoftwarePackage "ne1000 0.8.4-3vmw.670.3.99.32543355"
Export-ESXImageProfile -ImageProfile "ESXi-6.7.0-20191204001-NUC" -ExportToISO -filepath ESXi-6.7.0-20191204001-NUC.iso
```

### Upgrade with offline package

From ESXi node

#### Create offline package

Start a Powershell session with admin privileges

```powershell
> Set-ExecutionPolicy RemoteSigned
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> .\ESXi-Customizer-PS.ps1 -v70 -pkgDir .\ -ozip
```

> Change `-v70` by required version

Available versions are listed in [this page](https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml)


#### Upgrade ESXi software

It is assuming you have a VMFS configured to point to a NFS server to access /vmfs/volumes/nfs-storage-applications/vmware/ESXi\ Customize/

```shell
# Open HTTP Client
esxcli network firewall ruleset set -e true -r httpClient

# Update package (and not install to not override custom VIB)
esxcli software profile update \
    -d /vmfs/volumes/nfs-storage-applications/vmware/ESXi\ Customize/ESXi-7.0U2d-18538813-standard-customized.zip \
    -p ESXi-7.0U2d-18538813-standard-customized

# Deactivate HTTP Client
esxcli network firewall ruleset set -e false -r httpClient

# Reboot server to apply
reboot
```

> Don't forget to update both filename and package name

### Install USB NIC package

USB drivers are maintained by [vmware flings](https://flings.vmware.com/) and can be downloaded directly from [here](https://flings.vmware.com/usb-network-native-driver-for-esxi)

```shell
esxcli software vib install \
    -d /vmfs/volumes/nfs-storage-applications/vmware/ESXi\ Customize/ESXi702-VMKUSB-NIC-FLING-47140841-component-18150468.zip
```

Script example to reconfigure vswitch when usb interface comes up:

```shell
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
- `ESXi-Customizer-PS` by [VFront.de](https://www.v-front.de/p/esxi-customizer-ps.html) / [Github repository](https://github.com/VFrontDe/ESXi-Customizer-PS)
- [ESXi Patch tracker](https://esxi-patches.v-front.de/)
- [Home Lab HW](https://blog.labvl.net/homelab/homelab-p1/) (racking, cabling, components)
