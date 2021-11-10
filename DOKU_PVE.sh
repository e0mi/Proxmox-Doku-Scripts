#!/bin/bash
i=0
read -p "PVE IP: " PVE_HOST_IP
read -p "Pfad für Doku: " DOKU_PATH
read -s -p "PVE Root Password: " PVE_PASSWORD
echo -e '\n started'
start=$(date +%s)
mkdir -p $DOKU_PATH
mkdir -p $DOKU_PATH/node
mkdir -p $DOKU_PATH/vms
mkdir -p $DOKU_PATH/container

echo "0%"
curl --silent --insecure --data "username=root@pam&password="$PVE_PASSWORD https://$PVE_HOST_IP:8006/api2/json/access/ticket | jq --raw-output '.data.ticket' | sed 's/^/PVEAuthCookie=/' > cookie

NODE_COUNT=$(curl --silent --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/ | jq --raw-output '.data[].node' | wc -l)
PROGRESS_STEP=$((90/$NODE_COUNT))
curl --silent --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/ | jq --raw-output '.data[].node' |
while IFS= read -r node
    do
    scp -rq root@$PVE_HOST_IP:/etc/pve/nodes/$node/qemu-server/* $DOKU_PATH/vms 2>&1
    scp -rq root@$PVE_HOST_IP:/etc/pve/nodes/$node/lxc/* $DOKU_PATH/container 2>&1
     #########################################
     ####         Build Node List         ####
     #########################################
    version=$(curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/status  | jq --raw-output '.data.pveversion' | cut -d"/" -f2)
    ReadIP=$(curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/network/vmbr0/  | jq --raw-output '.data.address')
    cpumodel=$(curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/status | jq --raw-output '.data.cpuinfo.model')
    cpucount=$(curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/status | jq --raw-output '.data.cpuinfo.cpus')
    cpusokets=$(curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/status | jq --raw-output '.data.cpuinfo.sockets')
    rambyte=$(curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/status | jq --raw-output '.data.memory.total')
    vmbr0=$(curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/network/vmbr0/  | jq --raw-output '.data.address')
    vmbr42=$(curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/network/vmbr42/  | jq --raw-output '.data.address')
    #HW_Model=$(ssh root@$ReadIP -i $SSH_KEY "lshw -short | grep system" | cut -d" " -f37,38,39,40,41,42,43,44,45,46,47,48,49,50)
    echo -e '# '$node' \n\n Quelle: PVE UI \n\n ## System\n\n' > $DOKU_PATH/node/$node.md
    echo -e '* Proxmox V'$version >> $DOKU_PATH/node/$node.md
    echo -e '* UI : [https://'$ReadIP':8006](https://'$ReadIP':8006)' >> $DOKU_PATH/node/$node.md
    echo -e '* Standort: §§TODO' >> $DOKU_PATH/node/$node.md
    echo -e '* CPU:'$cpucount' x '$cpumodel' ('$cpusokets' Sockets)' >> $DOKU_PATH/node/$node.md
    echo -e '* RAM: '$((rambyte/1024/1024/1024))'GB\n\n\n\n' >> $DOKU_PATH/node/$node.md
    echo -e '## Netz\n\n\n\n' >> $DOKU_PATH/node/$node.md
    echo -e '## IP/Hostname\n\n' >> $DOKU_PATH/node/$node.md
    echo -e ' Interface | IP | Zweck \n -------|-------|-------|' >> $DOKU_PATH/node/$node.md
    echo -e ' vmbr0 | '$vmbr0'| Management' >> $DOKU_PATH/node/$node.md
    echo -e ' vmbr42 | '$vmbr42'| Storage\n\n' >> $DOKU_PATH/node/$node.md
    echo -e '## Hardware\n\n' >> $DOKU_PATH/node/$node.md
    echo -e 'Model: '§§TODO'\n\n\n'  >> $DOKU_PATH/node/$node.md
    echo -e 'Disks:\n\n'  >> $DOKU_PATH/node/$node.md
    echo -e ' dev | Model | Serial | FS \n -------|-------|-------|-------|' >> $DOKU_PATH/node/$node.md
    curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json//nodes/$node/disks/list | jq -r '.data[] | .devpath + " | " + .model + " | " + .serial + " | " + .used' >> $DOKU_PATH/node/$node.md
    curl --silent --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/disks/zfs/ | jq --raw-output '.data[].name' |
        while IFS= read -r zpool
            do
              echo -e '\n\n Disks Usage:\n'  >> $DOKU_PATH/node/$node.md
              echo -e $zpool'\n\n' >> $DOKU_PATH/node/$node.md
              curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json//nodes/$node/disks/zfs/$zpool | jq -r '.data.children[0].name ' >> $DOKU_PATH/node/$node.md
              curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json//nodes/$node/disks/zfs/$zpool | jq -r '"* " + .data.children[0].children[].name ' >> $DOKU_PATH/node/$node.md
        done
 #########################################
 ####          Build VM List          ####
 #########################################
    echo -e '\n\n'$node'\n\n' >> $DOKU_PATH/vmlist.md 
    echo -e ' VMID | VM Name \n -------|-------|' >> $DOKU_PATH/vmlist.md
    curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json//nodes/$node/qemu/  | jq -r '.data[] | .vmid + " | " + .name' >> $DOKU_PATH/vmlist.md
 #########################################
 ####     Build LX-Container List     ####
 #########################################
    echo -e '\n\n'$node'\n\n' >> $DOKU_PATH/lxclist.md 
    echo -e ' VMID | VM Name \n -------|-------|' >> $DOKU_PATH/lxclist.md
    curl --silent  --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json//nodes/$node/lxc/  | jq -r '.data[] | .vmid + " | " + .name' >> $DOKU_PATH/lxclist.md
    

    curl --silent --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/$node/qemu/ | jq --raw-output '.data[].vmid' |
                while IFS= read -r vmid
                      do
                      VM_Network=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.net0') 
                      VM_Cores=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.cores')
                      VM_Name=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.name')
                      VM_Sockets=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.sockets')
                      VM_Notes=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.description')
                      VM_OS=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.ostype')
                      VM_IO0=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.virtio0')
                      VM_IO1=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.virtio1')
                      VM_IO2=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.virtio2')
                      VM_IO3=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.virtio3')
                      VM_IO4=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.virtio4')
                      VM_IDE0=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.ide0')
                      VM_IDE1=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.ide1')
                      VM_IDE2=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.ide2')
                      VM_IDE3=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.ide3')
                      VM_IDE4=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.ide4')
                      VM_SCSI0=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.scsi0')
                      VM_SCSI1=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.scsi1')
                      VM_SCSI2=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.scsi2')
                      VM_SCSI3=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.scsi3')
                      VM_SCSI4=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.scsi4')
                      VM_RAM=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.memory')
                      VM_Agent=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.agent')
                      VM_SartonBoot=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.onboot')
                      VM_unused0=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.unused0')
                      VM_unused1=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.unused1')
                      VM_unused2=$(curl --silent  --insecure --cookie "$(<cookie)" https://10.29.2.28:8006/api2/json//nodes/$node/qemu/$vmid/config | jq --raw-output '.data.unused2')
                      VM_Agend=$(if [ $VM_Agent == 1 ]; then echo 'ja'; else echo 'nein'; fi )
                        if [ $VM_unused0 != "null" ]; then echo -e '## Rückfragen \n\n Warum gibts hier die unused0 - kann die weg oder muss es dokumentiert werden warum die da ist und wie lange sie warum wo bleibt?'; fi >> $DOKU_PATH/vms/$vmid.md
                        if [ $VM_unused1 != "null" ]; then echo -e '## Rückfragen \n\n Warum gibts hier die unused1 - kann die weg oder muss es dokumentiert werden warum die da ist und wie lange sie warum wo bleibt?'; fi >> $DOKU_PATH/vms/$vmid.md
                        if [ $VM_unused2 != "null" ]; then echo -e '## Rückfragen \n\n Warum gibts hier die unused2 - kann die weg oder muss es dokumentiert werden warum die da ist und wie lange sie warum wo bleibt?'; fi >> $DOKU_PATH/vms/$vmid.md
                      echo -e '## Meta\n\n' >> $DOKU_PATH/vms/$vmid.md
                      echo -e $VM_Notes >> $DOKU_PATH/vms/$vmid.md
                      echo -e ' - '$VM_OS >> $DOKU_PATH/vms/$vmid.md
                      echo -e ' - Storage' >> $DOKU_PATH/vms/$vmid.md
                        if [ $VM_IO0 != "null" ]; then echo -e '   - ' $VM_IO0 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IO1 != "null" ]; then echo -e '   - ' $VM_IO1 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IO2 != "null" ]; then echo -e '   - ' $VM_IO2 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IO3 != "null" ]; then echo -e '   - ' $VM_IO3 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IO4 != "null" ]; then echo -e '   - ' $VM_IO4 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IDE0 != "null" ]; then echo -e '   - ' $VM_IDE0 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IDE1 != "null" ]; then echo -e '   - ' $VM_IDE1 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IDE2 != "null" ]; then echo -e '   - ' $VM_IDE2 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IDE3 != "null" ]; then echo -e '   - ' $VM_IDE3 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_IDE4 != "null" ]; then echo -e '   - ' $VM_IDE4 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_SCSI0 != "null" ]; then echo -e '   - ' $VM_SCSI0 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_SCSI1 != "null" ]; then echo -e '   - ' $VM_SCSI1 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_SCSI2 != "null" ]; then echo -e '   - ' $VM_SCSI2 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_SCSI3 != "null" ]; then echo -e '   - ' $VM_SCSI3 >> $DOKU_PATH/vms/$vmid.md; fi
                        if [ $VM_SCSI4 != "null" ]; then echo -e '   - ' $VM_SCSI4 >> $DOKU_PATH/vms/$vmid.md; fi
                done
(( i++ ))
PROGRESS=$(($i*PROGRESS_STEP))
echo -e $PROGRESS' %'

done
echo "90 %"
ls -1 $DOKU_PATH/vms/*.conf |
while IFS= read -r file
    do
    vm=$(echo $file | cut -d"/" -f3 | cut -d"." -f1)
    echo -e '\n\n## Config\n\n~~~~' >> $DOKU_PATH/vms/$vm.md
    cat $file >> $DOKU_PATH/vms/$vm.md
    echo -e '~~~' >> $DOKU_PATH/vms/$vm.md
done
echo "95 %"
ls -1 $DOKU_PATH/container/*.conf |
while IFS= read -r file
    do
    vm=$(echo $file | cut -d"/" -f3 | cut -d"." -f1)
    echo -e '\n\n## Config\n\n~~~~' >> $DOKU_PATH/container/$vm.md
    cat $file >> $DOKU_PATH/container/$vm.md
    echo -e '~~~' >> $DOKU_PATH/container/$vm.md
done



rm -f $DOKU_PATH/vms/*.conf 
end=$(date +%s)
echo "100%"
echo "claimed time:" $(($end - $start)) "seconds"