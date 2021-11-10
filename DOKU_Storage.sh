#!/bin/bash
i=0
read -p "PVE IP: " PVE_HOST_IP
read -p "Pfad für Doku: " DOKU_PATH
read -p "Storage Name" STORAGE_NAME

read -s -p "PVE Root Password: " PVE_PASSWORD
echo -e '\n started'
start=$(date +%s)
mkdir -p $DOKU_PATH
mkdir -p $DOKU_PATH/node
mkdir -p $DOKU_PATH/vms
mkdir -p $DOKU_PATH/container

curl --silent --insecure --data "username=root@pam&password="$PVE_PASSWORD https://$PVE_HOST_IP:8006/api2/json/access/ticket | jq --raw-output '.data.ticket' | sed 's/^/PVEAuthCookie=/' > cookie
curl --silent --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json/nodes/ | jq --raw-output '.data[].node' |

curl --silent --insecure --cookie "$(<cookie)" https://$PVE_HOST_IP:8006/api2/json//nodes/pve13/storage/$STORAGE_NAME/content | jq --raw-output '.data[].volid' |
while IFS= read -r volid
    do
    
    echo -e ' Interface | IP | Zweck \n -------|-------|-------|' >> $DOKU_PATH/node/$STORAGE_NAME.md
    echo -e ' [ ] | '$vmbr0'| Management' >> $DOKU_PATH/node/$node.md
    echo -e ' vmbr42 | '$vmbr42'| Storage\n\n' >> $DOKU_PATH/node/$node.md
                done

done
ls -1 $DOKU_PATH/vms/*.conf |
while IFS= read -r file
    do
    vm=$(echo $file | cut -d"/" -f3 | cut -d"." -f1)
    echo -e '\n\n## Config\n\n~~~~' >> $DOKU_PATH/vms/$vm.md
    cat $file >> $DOKU_PATH/vms/$vm.md
    echo -e '~~~' >> $DOKU_PATH/vms/$vm.md
done
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
echo "claimed time:" $(($end - $start)) "seconds"