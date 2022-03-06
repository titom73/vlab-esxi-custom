#!/bin/sh

UBUNTUVM='Vm-name-to-keep-active'
VMS=`vim-cmd /vmsvc/getallvms | tail -n+2 | awk '{print $1","$2}'`
for vm in ${VMS}
do
        vmID=`echo $vm | cut -d',' -f1`
        vmName=`echo $vm | cut -d',' -f2`
        if [ $vmName != $UBUNTUVM ]
        then
                echo "Power off $vmName"
                vim-cmd vmsvc/power.shutdown $vmID
        fi
done