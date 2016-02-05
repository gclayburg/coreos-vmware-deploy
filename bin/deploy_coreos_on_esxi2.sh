#!/bin/bash
# William Lam
# www.virtuallyghetto.com
# New version of script to automate the deployment of CoreOS image w/VMware Tools onto ESXi
#
# Changelog
# 12/21/2014  Gary Clayburg  Added many more options and error checking
CHANNEL=alpha
DEBUG_ONLY=false
SKIP_DOWNLOAD=false
UPLOAD_NEW_IMAGE=true

do_shell(){
# Execute command in shell, while logging complete command to stdout
    echo "$(date +%Y-%m-%d_%T) --> $*"
    eval "$*"
    STATUS=$?
    return $STATUS
}

usage(){
  echo "Usage: $0 [OPTIONS] file"
  echo "Options:"
  echo "  -h,--help  Show usage only"
  echo "  -d,--debug  Show user_data that will be created, but do not change anything or create any image"
  echo "  -s,--skip_download   Do not attempt to download of latest coreos"
  echo "  -c,--channel [channel=alpha]  Use specific coreos channel: alpha, beta, stable"
  echo "  -u,--update_user_data  Only create and deploy user_data iso image.  VM must already exist"
  echo "  --core_os_hostname=worker1  Set hostname of new vm image to worker1"
  echo ""
  exit 3
}

update_user_data(){
  if [[ -f $1 ]]; then
    # assume user provided a file with custom settings and user_data file
    . $1
  else
    # use default user_data with etcd running on all nodes and static IP
    echo "File not found: $1"
    usage
  fi
  # CoreOS VMX URL
  CORE_OS_VMX_URL=http://${CHANNEL}.release.core-os.net/amd64-usr/current/coreos_production_vmware.vmx

  # CoreSO VMDK URL
  CORE_OS_VMDK_URL=http://${CHANNEL}.release.core-os.net/amd64-usr/current/coreos_production_vmware_image.vmdk.bz2


  # Name of the CoreOS Cloud Config ISO
  CLOUD_CONFIG_ISO=${CORE_OS_HOSTNAME}-config.iso

  echo "hostname:   $CORE_OS_HOSTNAME"
  echo "VM name:    $VM_NAME"
  echo "VM network: $VM_NETWORK"
  echo ""
  echo "user_data:"
  cat ${TMP_CLOUD_CONFIG_DIR}/openstack/latest/user_data
  if [[ "${DEBUG_ONLY}" = true ]]; then
    exit
  fi

  ##### DO NOT EDIT BEYOND HERE #####

  CORE_OS_DATASTORE_PATH=/vmfs/volumes/${ESXI_DATASTORE}/${VM_NAME}
  MKDIR_COMMAND=$(eval echo mkdir -p ${CORE_OS_DATASTORE_PATH})
  CORE_OS_ESXI_SETUP_SCRIPT=setup_core_os_on_esxi.sh

  echo "Checking if bunzip2 exists ..."
  if ! which bunzip2 > /dev/null 2>&1; then
	  echo "Error: bunzip2 does not exist on your system"
	  exit 1
  fi

  echo "Checking if mkisofs exists ..."
  if ! which mkisofs > /dev/null 2>&1; then
	echo "Error: mkisofs does not exist on your system"
	exit 1
  fi

  echo "Checking if expect exists ..."
  if ! which expect > /dev/null 2>&1; then
  	echo "Error: expect does not exist on your system"
  	exit 1
  fi
  if [ "${SKIP_DOWNLOAD}" = false ]; then
    echo "Download CoreOS VMX Configuration File ..."
    curl -O "${CORE_OS_VMX_URL}"

    echo "Downloading CoreOS VMDK Disk File ..."
    curl -O "${CORE_OS_VMDK_URL}"

    echo "Extracting CoreOS VMDK ..."
    if [[ -f "coreos_production_vmware_image.vmdk" ]]; then
      rm "coreos_production_vmware_image.vmdk"
    fi
    bunzip2 $(ls | grep ".bz2")
  fi

  CORE_OS_VMDK_FILE=$(ls | grep ".vmdk")
  CORE_OS_VMX_FILE=$(ls | grep ".vmx")

  # ghetto way of creating VM directory
  echo "Creating ${CORE_OS_DATASTORE_PATH} ..."
  VAR=$(expect -c "
  spawn ssh -o StrictHostKeyChecking=no ${ESXI_USERNAME}@${ESXI_HOST} $MKDIR_COMMAND
  match_max 100000
  expect {
    \"*?assword:*\" {
  #    puts \"filling in password\"
      send \"$ESXI_PASSWORD\r\"
      expect eof
    } eof {
  #    puts \"no password  needed\"
    }
  }
  ")



  echo "Creating Cloud Config ISO ..."
  mkisofs -R -input-charset utf-8 -V config-2 -o ${CLOUD_CONFIG_ISO} ${TMP_CLOUD_CONFIG_DIR}

  # Using HTTP put API to upload both VMX/VMDK
  echo "Uploading CoreOS Cloud-Config ISO file to ${ESXI_DATASTORE} ... https://${ESXI_HOST}/folder/${VM_NAME}/${CLOUD_CONFIG_ISO}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

  HTTPSTATUS=$(curl -s -o /dev/null -w "%{http_code}" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}"  "https://${ESXI_HOST}/folder/${VM_NAME}/${CLOUD_CONFIG_ISO}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}")
  if [[ $HTTPSTATUS -eq "200" ]]; then
    echo ""
    echo "WARNING: ${VM_NAME}/${CLOUD_CONFIG_ISO} file already exists in VMware datastore."
    echo "         The VM must be powered off in order for this iso file to be replaced"
    echo "         in the datastore."
  fi
  curl -H "Content-Type: application/octet-stream" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}" --data-binary "@${CLOUD_CONFIG_ISO}" -X PUT "https://${ESXI_HOST}/folder/${VM_NAME}/${CLOUD_CONFIG_ISO}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

}

upload_new_image(){
  # Using HTTP put API to upload both VMX/VMDK
  echo "Uploading CoreOS VMDK file to ${ESXI_DATASTORE} ..."
  curl -H "Content-Type: application/octet-stream" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}" --data-binary "@${CORE_OS_VMDK_FILE}" -X PUT "https://${ESXI_HOST}/folder/${VM_NAME}/${CORE_OS_VMDK_FILE}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

  echo "Uploading CoreOS VMX file to ${ESXI_DATASTORE} ..."
  curl -H "Content-Type: application/octet-stream" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}" --data-binary "@${CORE_OS_VMX_FILE}" -X PUT "https://${ESXI_HOST}/folder/${VM_NAME}/${CORE_OS_VMX_FILE}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

  # Creates script to convert VMDK & register on ESXi host
  echo "Creating script to convert and register CoreOS VM on ESXi ..."
  cat > ${CORE_OS_ESXI_SETUP_SCRIPT} << __CORE_OS_ON_ESXi__
#!/bin/sh
# William Lam
# www.virtuallyghetto.com
# Auto Geneated script to automate the conversion of VMDK & regiration of CoreOS VM

# Change to CoreOS directory
cd ${CORE_OS_DATASTORE_PATH}

# Convert VMDK from 2gbsparse from hosted products to Thin
vmkfstools -i ${CORE_OS_VMDK_FILE} -d thin coreos.vmdk

# Remove the original 2gbsparse VMDKs
rm ${CORE_OS_VMDK_FILE}

# Update CoreOS VMX to reference new VMDK
sed -i 's/${CORE_OS_VMDK_FILE}/coreos.vmdk/g' ${CORE_OS_VMX_FILE}

# Update CoreOS VMX w/new VM Name
sed -i "s/displayName.*/displayName = \"${VM_NAME}\"/g" ${CORE_OS_VMX_FILE}

# Update CoreOS VMX to map to VM Network
echo "ethernet0.networkName = \"${VM_NETWORK}\"" >> ${CORE_OS_VMX_FILE}

# Update CoreOS VMX to include CD-ROM & mount cloud-config ISO
cat >> ${CORE_OS_VMX_FILE} << __CLOUD_CONFIG_ISO__
ide0:0.deviceType = "cdrom-image"
ide0:0.fileName = "${CLOUD_CONFIG_ISO}"
ide0:0.present = "TRUE"
__CLOUD_CONFIG_ISO__

# Register CoreOS VM which returns VM ID
VM_ID=\$(vim-cmd solo/register ${CORE_OS_DATASTORE_PATH}/${CORE_OS_VMX_FILE})

# Upgrade CoreOS Virtual Hardware from 4 to 9
echo "Upgrade CoreOS Virtual Hardware from 4 to 9"

vim-cmd vmsvc/upgrade \${VM_ID} vmx-09

# PowerOn CoreOS VM
echo "PowerOn CoreOS VM"
vim-cmd vmsvc/power.on \${VM_ID}
echo "VM ${VM_NAME} is now running using hostname: ${CORE_OS_HOSTNAME}"
#The first time coreos boots up, it will use DHCP to get a random IP address.  Later in the boot process, coreos will write the static.network file which overrides the DHCP behavior for the next boot.
#This workaround reboots this new server to allow it to use this static IP
#echo "Wating 60 seconds for power.on"
#sleep 60
#vim-cmd vmsvc/power.shutdown \${VM_ID}
#echo "Waiting for power.off"
#while vim-cmd vmsvc/power.getstate \${VM_ID} | grep on; do
#  echo -n "."
#  sleep 1
#done
#vim-cmd vmsvc/power.on \${VM_ID}



__CORE_OS_ON_ESXi__
  chmod +x ${CORE_OS_ESXI_SETUP_SCRIPT}

  echo "Running ${CORE_OS_ESXI_SETUP_SCRIPT} script against ESXi host ..."
  #todo use expect to supply password to ssh,
  # and not prompt user for password if they have not setup ssh keys between the client and esxi server
  ssh -o ConnectTimeout=300 ${ESXI_USERNAME}@${ESXI_HOST} < ${CORE_OS_ESXI_SETUP_SCRIPT}

#SCRIPT_OUT=$(expect -c "
#  spawn scp ${CORE_OS_ESXI_SETUP_SCRIPT} ${ESXI_USERNAME}@${ESXI_HOST}:
#  match_max 100000
#  expect {
#    \"*?assword:*\" {
#      send \"$ESXI_PASSWORD\r\"
#      expect eof
#    } eof {
#    }
#  }

#  spawn ssh -o ConnectTimeout=300 root@paladin \"chmod 755 ${CORE_OS_ESXI_SETUP_SCRIPT}; ./${CORE_OS_ESXI_SETUP_SCRIPT} \"
#  match_max 100000
#  expect {
#    \"*?assword:*\" {
#      send \"$ESXI_PASSWORD\r\"
#      expect eof
#    } eof {
#    }
#  }

#")
# echo "output: $SCRIPT_OUT"
}
#echo "Cleaning up ..."
#rm -f ${CORE_OS_ESXI_SETUP_SCRIPT}
#rm -f ${CORE_OS_VMDK_FILE}
#rm -f ${CORE_OS_VMX_FILE}
#rm -f ${CLOUD_CONFIG_ISO}
#rm -rf ${TMP_CLOUD_CONFIG_DIR}

while [[ $# > 1 ]]; do
  key="$1"
  shift
  case $key in
    -s|--skip_download)
      SKIP_DOWNLOAD=true
    ;;
    -u|--update_user_data)
      SKIP_DOWNLOAD=true
      UPLOAD_NEW_IMAGE=false
    ;;
    -c|--channel)
      CHANNEL="$1"
      shift
    ;;
    -d|--debug)
      DEBUG_ONLY=true
    ;;
    -h|--help|-?)
      usage
      shift
    ;;
    --*=*)  # i.e.,  --core_os_hostname=mink1
      UPCASE=${key^^} #upcase
      UPNAME=${UPCASE#--}  #remove --
      SHORTNAME=${UPNAME%%=*} #remove value
      SHORTVAL=${key#*=} #remove name
      echo "overriding value ${SHORTNAME}=${SHORTVAL}"
      eval "${SHORTNAME}=${SHORTVAL}"
    ;;
    *)
      usage
            # unknown option
    ;;
  esac
done

update_user_data $1
if [[ "${UPLOAD_NEW_IMAGE}" = true ]]; then
  upload_new_image
fi
