#!/bin/bash

set -e
THIS_SCRIPT=$(realpath $0)
FUNCTION="$1"
FUNPARAM="$2"

export SSHPASS='Testit123!'

JSON_LOG_DIR='json.logs'

USER='manage'
TARGETS=("corvault-1a" "corvault-2a" "corvault-3a")
#TARGETS=("corvault-1a" )
#TARGETS=("corvault-3a")

# provides a wee bit more verbosity to stderr
DBG=0
# prepatory command to the corvault
BASE_CMD='set cli-parameters json; '

CheckForPreReqs() {
	MISSING=""
	for CHK in jq sshpass dialog bc sdparm
	do
		if ! [ -x "$(command -v $CHK)" ]
		then
			MISSING="$MISSING $CHK"
			echo "$CHK is missing"
		fi
	done
	if [ "X${MISSING}" != "X" ] ; then
		echo "Please install: $MISSING"
		exit 1
	fi
}

if [[ ! -d "${JSON_LOG_DIR}" ]]; then
	mkdir "${JSON_LOG_DIR}"
fi
truncate -s 0 cmd.log
# interesting sysfs paths for coorelating LUNs to host HBA ports and kdevs
#cat /sys/devices/*/*/*/host*/phy-*/sas_phy/*/sas_address | sort -u | cut -c 15-
#cat /sys/devices/pci*/*/*/host*/port*/end_device*/target*/*/sas_address | sort -u


# kind of like atop, but for Corvault
monitor_io() {
	while [ 1 ] ; do 
	date
	sshpass -e ssh manage@corvault-1a \
		'set cli-parameters json; show controller-statistics' \
		| grep bytes-per-second \
		| grep -v numeric
		sleep 10
	done
}
# Dispatches commands to the Corvault in a way that's easy to capture.
DoSSH() {
	sshpass -e $@
}
# The "meat & potatoes" - dispatches commands parses (and fixes) the JSON output
DoCmd() {
	TGT="${1}"
	shift
	REPLY_FILE="${TGT}.json"
	[[ $DBG != 0 ]] && echo "TGT: $TGT  CMD: $BASE_CMD $@" 1>&2
	SSHSOCKET=/tmp/$TGT.ssh.socket
	SSHOPTS="-o ControlPath=$SSHSOCKET -o ControlMaster=auto -o ControlPersist=10m -o StrictHostKeyChecking=accept-new"
	echo "ssh ${USER}@${TGT} ${BASE_CMD} $@" >>./cmd.log
	REPLY=$(DoSSH "ssh ${SSHOPTS} ${USER}@${TGT} ${BASE_CMD} $@")
	# Pull off the commented lines that contain the commands sent to the target
	[[ $DBG != 0 ]] && printf "REPLY: %s\n" "$REPLY" 1>&2
	REQ=$(echo "$REPLY" | egrep '^#.*' | sed -e 's/^#[ ]*//g' -e '/^$/d' | sed -e :a -e '$!N; s/\n/; /; ta')
	[[ $DBG != 0 ]] && printf "REQ: $REQ\n" 1>&2
	JSON=$(printf "%s\n" "$REPLY" | awk '/#  /,0' | egrep -v '^# .*' |  sed -e :a -e '$!N;  ta')
	[[ $DBG != 0 ]] && printf "JSON: %s\n" "$JSON" 1>&2
	RESP=$(echo ${JSON} | jq -r '.status[].response')
	STAT=$(echo ${JSON} | jq -r '.status[]."response-type"')
	[[ $DBG != 0 ]] && printf "RESP: %s\n" "$RESP" 1>&2
	[[ $DBG != 0 ]] && printf "STAT: %s\n" "$STAT" 1>&2
	if [ "${STAT}" != "Success" ] ; then
		echo "${REPLY}" >"${REPLY_FILE}"
		#echo "Error: $BASE_CMD $@" 1>&2;
		echo "Status: ${STAT} ${RESP}" 1>&2;
		#echo "Response: ${RESP}" 1>&2;
		#echo "See ${REPLY} for full JSON return data" 1>&2;
		exit 1
	fi
	[[ $DBG != 0 ]] && echo "Status: ${STAT}" 1>&2
	printf "%s\n" "$JSON"
}
ShowInquiryJSON() {
	TGT=$1
	CMD="show inquiry"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_inquiry.json"
}
ShowSensorStatusJSON() {
	TGT=$1
	CMD="show sensor-status"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_sensor-status.json"
}
ShowConfigurationJSON() {
	TGT=$1
	CMD="show configuration"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_configuration.json"
}
ShowHostPhyStatisticsJSON() {
	TGT=$1
	CMD="show host-phy-statistics"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_host-phy-satistics.json"
}
ShowHostsGroupsJSON() {
	TGT=$1
	CMD="show host-groups"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_host-groups.json"
}
ShowExpanderStatusStatsJSON() {
	TGT=$1
	CMD="show expander-status stats"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_expander-status.json"
}
ShowDiskGroupsJSON() {
	TGT="$1"
	CMD="show disk-groups"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_disk-groups.json"
}
ShowDisksJSON() {
	TGT=$1
	CMD="show disks"
	# Fix the fork up introduced by R010 where a percent sign was injected into a value.
	DoCmd ${TGT} "${CMD}" | tr -d '%' | sed 's/current-job-completion/current-job-completion-percent/g' \
		 | tee "${JSON_LOG_DIR}/${TGT}_show_disks.json"
}
ShowVolumesJSON() {
	TGT="$1"
	CMD="show volumes"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_volumes.json"
}
ShowInitiatorsJSON() {
	TGT="$1"
	CMD="show initiators"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_initiators.json"
}
ShowMapsJSON() {
	TGT="$1"
	CMD="show maps"
	DoCmd ${TGT} "${CMD}" | tee "${JSON_LOG_DIR}/${TGT}_show_maps.json"
}
ShowMpt3SasHBAsJSON() {
	ENTRY_COUNT=0
	PREFIX="  {\n"
	printf "{\n\"mpt3hba\":[\n"
	for X in $(find /sys/class/scsi_host/host*/ | grep host_sas_address)
	do
		ENTRY_COUNT=$((ENTRY_COUNT + 1))
		CTRLR_PATH=$(dirname $(realpath $X))
		PCI_ADDR=$(printf "$CTRLR_PATH" | awk -F '/' '{print $6}')
		PCI_HOST_PATH="$(dirname $(dirname $(dirname $CTRLR_PATH)))"
		PCI_VENDOR="$(cat $PCI_HOST_PATH/vendor)"
		PCI_SUBSYSTEM_VENDOR="$(cat $PCI_HOST_PATH/subsystem_vendor)"
		PCI_SUBSYSTEM_DEVICE="$(cat $PCI_HOST_PATH/subsystem_device)"
		UNIQUE_ID="$(cat $CTRLR_PATH/unique_id)"
		SAS_ADDR="$(cat $CTRLR_PATH/host_sas_address | sed 's/0x//g')"
		BOARD_NAME="$(cat $CTRLR_PATH/board_name | sed 's/ /_/g')"
		BOARD_ASSEMBLY="$(cat $CTRLR_PATH/board_assembly)"
		VERSION_BIOS="$(cat $CTRLR_PATH/version_bios)"
		VERSION_FW="$(cat $CTRLR_PATH/version_fw)"
		VERSION_MPI="$(cat $CTRLR_PATH/version_mpi)"
		VERSION_NVDATA="$(cat $CTRLR_PATH/version_nvdata_persistent)"
		VERSION_PRODUCT="$(cat $CTRLR_PATH/version_product)"
		printf $PREFIX
		printf "  \"sysfs-path\": \"$CTRLR_PATH\",\n"
		printf "  \"unique-id\": \"$UNIQUE_ID\",\n"
		printf "  \"pci-vendor\": \"$PCI_VENDOR\",\n"
		printf "  \"pci-subsystem-vendor\": \"$PCI_SUBSYSTEM_VENDOR\",\n"
		printf "  \"pci-subsystem-device\": \"$PCI_SUBSYSTEM_DEVICE\",\n"
		printf "  \"board-name\": \"$BOARD_NAME\",\n"
		printf "  \"board-assembly\": \"$BOARD_ASSEMBLY\",\n"
		printf "  \"sas-address\": \"$SAS_ADDR\",\n"
		printf "  \"pci-address\": \"$PCI_ADDR\",\n"
		printf "  \"version-fw\": \"$VERSION_FW\",\n"
		printf "  \"version-bios\": \"$VERSION_BIOS\",\n"
		printf "  \"version-mpi\": \"$VERSION_MPI\",\n"
		printf "  \"version-nvdata\": \"$VERSION_NVDATA\",\n"
		printf "  \"version-product\": \"$VERSION_PRODUCT\"\n"
		PREFIX="  },\n{\n"
	done
	[[ $ENTRY_COUNT == 0 ]] || printf "  }\n"
	printf "]}\n" | tee "${JSON_LOG_DIR}/mpt3sas_hbas.json"
}
ShowMpt3SasHBAs() {
	printf "\nRUN: ${FUNCNAME[0]}\n"
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
           .mpt3hba[]? | "\t"
           + ."unique-id" + ",\t"
           + ."board-name" + ",\t"
           + ."version-product" + ",\t"
           + ."sas-address" + ",\t"
           + ."pci-address" + ",\t"
           + ."pci-vendor" + ",\t"
           + ."pci-subsystem-device" + ",\t"
           + ."version-fw"  + ",\t"
           + ."version-bios"  + ",\t"
           + ."version-mpi"  + ",\t"
           + ."version-nvdata"
EOF
)
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	HDR01=" UniqueID,"
	HDR02="          BoardName,"
	HDR03="  ChipSet,"
	HDR04="           SAS_Address,"
	HDR05="         PCI_Address,"
	HDR06="    Vendor,"
	HDR07=" Device,"
	HDR08=" FirmwareVer,"
	HDR09="        BiosVer,"
	HDR10="    MpiVer,"
	HDR11=" NvDataVer"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}${HDR06}${HDR07}${HDR08}${HDR09}${HDR10}${HDR11}"
	printf "$HDR\n"
	RESULT=$(ShowMpt3SasHBAsJSON | jq  -r "${JQ}")
	printf "${RESULT}\n"
}
GetInquiryNoHdr() {
	TGT=$1
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	 $T + ",\t" +
	 (
           ."product-info"[] | ."product-id" + ",\t"
         )
	 + ( 
             .inquiry[] 
             | ."object-name" + ",\t"
             + ."serial-number" + ",\t"
             + ."mc-fw" + ",\t" + ."sc-fw"
             + ",\t" + ."mc-loader" + ",\t"
             + ."sc-loader" + ",\t\t"
             + ."mac-address" + ",\t"
             + ."ip-address"
           )
EOF
)
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	RESULT=$(ShowInquiryJSON $TGT | jq --arg T "$TGT" -r "${JQ}")
	printf "${RESULT}\n"
}
GetInquiry() {
	printf "\nRUN: ${FUNCNAME[0]}\n"
	HDR00="controller,\t"
	HDR01="product-id,\t"
	HDR02="controller,\t"
	HDR03="serial,\t\t\t"
	HDR04="mc-fw,\t\t"
	HDR05="sc-fw,\t\t"
	HDR06="mc-loader,\t"
	HDR07="sc-loader,\t"
	HDR08="mac-address,\t\t"
	HDR09="ip-address"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}${HDR06}${HDR07}${HDR08}${HDR09}"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		GetInquiryNoHdr $TGT
	done
}
GetVolumesNoHdr() {
	TGT=$1
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	.volumes[]?
	 | $T + ",\t"
	 + ."owner" + ",\t"
	 + ."volume-name" +",\t"
	 + ."virtual-disk-name" + ",\t"
	 + ."size" + ",\t"
	 + ."serial-number" + ",\t" + (."wwn" | ascii_downcase) + ",\t"
	 + ."creation-date-time"
EOF
)
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	RESULT=$(ShowVolumesJSON $TGT | jq --arg T "$TGT" -r "${JQ}" | sed 's:%::g')
	printf "${RESULT}\n"
}
GetVolumes() {
	printf "\nRUN: ${FUNCNAME[0]}\n"
	HDR00="controller,\t"
	HDR01="owner,\t"
	HDR02="volume-name,\t"
	HDR03="name,\t"
	HDR04="size,\t\t"
	HDR05="serial-number,\t\t\t\t"
	HDR06="wwn-number,\t\t\t\t"
	HDR07="creation-date-time"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}${HDR06}${HDR07}"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		GetVolumesNoHdr $TGT
	done
}
GetInitiatorsNoHdr() {
	TGT=$1
	FILTERED=$2
	if [[ $FILTERED == 0 ]]; then
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	.initiator[]
	 | $T + ",\t"
	 + ."durable-id" + ",\t"
	 + .discovered + ",\t"
	 + .id + ",\t"
	 + (."host-port-bits-a"| tostring) + ",\t"
	 + (."host-port-bits-b"| tostring) + ",\t"
	 + .nickname
EOF
)
	else
	 #| if ."host-id" == "NOHOST" then ."host-id"="NOHOST " else ."host-id" = ."host-id" + "," end
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	.initiator[] | select(.discovered == "Yes") 
	 | $T + ",\t"
	 + ."durable-id" + ",\t"
	 + .discovered + ",\t"
	 + .id + ",\t"
	 + (."host-port-bits-a"| tostring) + ",\t"
	 + (."host-port-bits-b"| tostring) + ",\t"
	 + .nickname
EOF
)
	fi
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	RESULT=$(ShowInitiatorsJSON $TGT | jq --arg T "$TGT" -r "${JQ}")
	printf "${RESULT}\n"
}
GetInitiators() {
	TGT=$1
	FILTERED=1
	if [[ $FILTERED == 0 ]]; then
		printf "\nRUN: $TGT ${FUNCNAME[0]} (unfiltered)\n"
	else
		printf "\nRUN: $TGT ${FUNCNAME[0]} (filtered for only discovered initiators)\n"
	fi
	HDR00="controller,\t"
	HDR01="d-id,\t"
	HDR02="dscvrd,\t\t"
	HDR03="id,\t"
	HDR04="HostBitsA, "
	HDR05="HostBitsB,\t"
	HDR06="nickname"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}${HDR06}"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		GetInitiatorsNoHdr $TGT $FILTERED
	done
}
GetExpanderStatusStatsNoHdr(){
	TGT=$1
	FILTERED=$2
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	. | to_entries[] | select(.key |startswith("sas-status-controller")).value[]
	| $T + ",\t" 
	+ (."enclosure-id" | tostring) +  ",\t"
	+ (."baseplane-id" | tostring) + ",\t"
	+ (."expander-id" | tostring)  + ",\t"
	+ ."controller"  + ",\t" +
	(."phy-index"|tostring)  + ",\t"
	+  ."elem-status"  + ",\t"
	+ ."change-counter"  + ",\t"
	+ ."code-violations"  + ",\t"
	+ ."disparity-errors"  + ",\t"
	+ ."crc-errors" + ",\t"
	+ ."conn-crc-errors"  + ",\t"
	+ ."lost-dwords"  + ",\t"
	+ ."invalid-dwords"  + ",\t"
	+ ."reset-error-counter" + ",\t"
	+  ."flag-bits" 
EOF
)
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	RESULT=$(ShowExpanderStatusStatsJSON $TGT | jq --arg T "$TGT" -r "${JQ}")
	printf "${RESULT}\n"

}
GetExpanderStatusStats(){
	HDR00="controller,\t"
	HDR01="encl,\t"
	HDR02="bPlane,\t"
	HDR03="expndr, "
	HDR04="ctrlr, "
	HDR05="phy-idx, "
	HDR06="status,\t"
	HDR07="chg-cntr,\t"
	HDR08="violations,\t"
	HDR09="disparity,\t"
	HDR10="crc-err,\t"
	HDR11="conn-crc,\t"
	HDR12="lostdword,\t"
	HDR13="invlddword,\t"
	HDR14="reset-errcnt,\t"
	HDR15="flag-bits,\t"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}${HDR06}${HDR07}${HDR08}${HDR09}${HDR10}${HDR11}${HDR12}${HDR13}${HDR14}${HDR15}"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		GetExpanderStatusStatsNoHdr "$TGT" $FILTERED
	done
}
GetHostPhyStatisticsNoHdr() {
	TGT=$1
	FILTERED=$2
	if [[ $FILTERED == 0 ]]; then
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	."sas-host-phy-statistics"[]
	 | $T + ",\t"
	 + .port + "-" + (.phy|tostring) + ",\t"
	 + ."disparity-errors" +",\t"
	 + ."lost-dwords" + ",\t"
	 + ."invalid-dwords" + ",\t"
	 + ."reset-error-counter"
EOF
)
	else
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	."sas-host-phy-statistics"[]
	 |  select((((."disparity-errors" != "00000000")
	 or ."lost-dwords" != "00000000")
	 or ."invalid-dwords" != "00000000")
	 or ."reset-error-counter" != "00000000")
	 | $T + ",\t"
	 + .port + "-" + (.phy|tostring) + ",\t"
	 + ."disparity-errors" +",\t"
	 + ."lost-dwords" + ",\t"
	 + ."invalid-dwords" + ",\t"
	 + ."reset-error-counter"
EOF
)
	fi
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	RESULT=$(ShowHostPhyStatisticsJSON $TGT | jq --arg T "$TGT" -r "${JQ}")
	printf "${RESULT}\n"
}
GetHostPhyStatistics() {
	TGT=$1
	FILTERED=1
	if [[ $FILTERED == 0 ]]; then
		printf "\nRUN: ${FUNCNAME[0]} (unfiltered)\n"
	else
		printf "\nRUN: ${FUNCNAME[0]} (filtered for non-zero counters)\n"
	fi
	HDR00="controller,\t"
	HDR01="port,\t"
	HDR02="disparities,\t"
	HDR03="lost-dws,\t"
	HDR04="invalid-dws,\t"
	HDR05="reset-errs"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		GetHostPhyStatisticsNoHdr "$TGT" $FILTERED
	done
}
GetMapsNoHdr(){
	TGT=$1
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	."volume-view"[]?
	 | $T + ",\t"
	 + ."volume-serial" + ",\t"
	 + ."volume-view-mappings"[].identifier + ",\t"
	 + ."volume-name" + ",\t"
	 + ."volume-view-mappings"[].access + ",\t"
	 + ."volume-view-mappings"[].ports + ",\t"
	 + ."volume-view-mappings"[].nickname  + ",\t" + ."volume-view-mappings"[].lun
EOF
)
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	RESULT=$(ShowMapsJSON $TGT | jq --arg T "$TGT" -r "${JQ}")
	printf "${RESULT}\n"
}
GetMaps(){
	TGT=$1
	printf "\nRUN: ${FUNCNAME[0]}\n"
	HDR00="controller,\t"
	HDR01="volume-serial,\t                        "
	HDR02="volume-identifier,                      "
	HDR03="volume-name,    "
	HDR04="access,         "
	HDR05="ports,          "
	HDR06="nickname,       "
	HDR07="lun"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}${HDR06}${HDR07}"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		GetMapsNoHdr "$TGT"
	done
}
GetDisksNoHdr() {
	TGT="$1"
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	.drives[]? 
	 | $T + ",\t"
	 + ."durable-id" + ",\t" 
	 + ."disk-group" + ",\t"
	 + ."vendor" + ",\t"
	 + ."model" + ",\t"
	 + ."serial-number" + ",\t"
	 + (."blocksize"|tostring) + ",\t"
	 + ."size" + ",\t"
	 + ."temperature" + ",\t"
	 + ."health"
EOF
)
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	RESULT=$(ShowDisksJSON "${TGT}" | jq --arg T "$TGT" -r "${JQ}")
	printf "${RESULT}\n"
}
GetDisks() {
	printf "\nRUN: ${FUNCNAME[0]}\n"
	HDR00="controller,\t"
	HDR01="name,\t\t"
	HDR02="dgroup,\t"
	HDR03="vendor,\t\t"
	HDR04="model,\t\t"
	HDR05="serial,\t\t"
	HDR06="    blocksize,\t"
	HDR07="size,\t"
	HDR08="temperature,\t"
	HDR09="health"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}${HDR06}${HDR07}${HDR08}${HDR09}"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		GetDisksNoHdr "$TGT"
	done
}
GetDiskGroupsNoHdr() {
	TGT="$1"
	JQ=$(cat <<"EOF" | tr -d '\n\r\t'
	."disk-groups"[]?
	 | $T + ",\t"
	 + .name +",\t" + .size + ",\t"
	 + ."storage-type" + ",\t\t"
	 + .raidtype + ",\t\t"
	 + (."diskcount"|tostring)
	 + ",\t\t" + .owner + ",\t"
	 + ."serial-number"
EOF
)
	[[ $DBG != 0 ]] && printf "JQ : %s\n" "${JQ}" 1>&2
	RESULT=$(ShowDiskGroupsJSON "${TGT}" | jq --arg T "$TGT" -r "${JQ}")
	printf "${RESULT}\n"
}
GetDiskGroups() {
	printf "\nRUN: ${FUNCNAME[0]}\n"
	HDR00="controller,\t"
	HDR01="name,   "
	HDR02="size,           "
	HDR03="storage-type,\t"
	HDR04="raid-type,\t"
	HDR05="disk-count,\t"
	HDR06="owner,\t"
	HDR07="serial-number"
	HDR="${HDR00}${HDR01}${HDR02}${HDR03}${HDR04}${HDR05}${HDR06}${HDR07}"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		GetDiskGroupsNoHdr "$TGT"
	done
}
GetDisksInDiskGroups() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	HDR="controller,\tdisk-group,\tdisks"
	printf "${HDR}\n"
	for TGT in "${TARGETS[@]}"
	do
		SHOWDISK=$(ShowDisksJSON $TGT)
		for DG in $(echo $SHOWDISK | jq -r '.drives[]? | ."disk-group"' | sort -u)
		do
			printf "$TGT,\t$DG\t"
			printf "$SHOWDISK\n" \
			| jq -r '.drives[]? | ."disk-group" + " " + ."location" ' \
			| grep $DG | awk -F ' ' '{print $2}' | tr '\n' ',' | sed 's/,$//g' ; printf "\n"
		done
	done
	
}
RemoveDiskGroup() {
	TGT=$1
	DG=$2
	printf "RUN: $TGT ${FUNCNAME[0]} $DG \n"
	CMD="remove disk-groups $DG"
	DoCmd ${TGT} ${CMD} | jq -r '.status[]."response-type"'
}
RemoveAllControllerDiskGroups() {
	TGT=$1
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	for SERIAL in $(ShowDiskGroupsJSON "${TGT}"  | jq -r '."disk-groups"[]? | ."serial-number"')
	do
		RemoveDiskGroup $TGT $SERIAL
	done
}
RemoveAllDiskGroupsFromAllControllers() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	for TGT in ${TARGETS[*]}; do
		RemoveAllControllerDiskGroups $TGT &
	done
	wait
}
RemoveAllInitiatorNickNames() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	for TGT in ${TARGETS[*]}; do
		CMD="delete host-groups delete-hosts all"
		printf "${TGT} ${CMD}  "
		DoCmd "${TGT}" "${CMD}" | jq -r '.status[]."response-type"'
		for NICK in $(ShowInitiatorsJSON $TGT  | jq -r '.initiator[]? | .nickname')
		do
			if [[ "X$NICK" != "$X" ]]; then
				CMD="delete initiator-nickname $NICK"
				printf "${TGT} ${CMD}  "
				DoCmd "${TGT}" "${CMD}" | jq -r '.status[]."response-type"' &
			fi
		done
		wait
	done

}
ResetHostSasLinks() {
	for TGT in "${TARGETS[@]}"; do
		printf "\nRUN: $TGT ${FUNCNAME[0]}\n"
		CMD="reset host-link ports A1"
		printf "  $CMD "
		DoCmd ${TGT} ${CMD} | jq -r '.status[]."response-type"'
		CMD="reset host-link ports B1"
		printf "  $CMD "
		DoCmd ${TGT} ${CMD} | jq -r '.status[]."response-type"'
	done
}
ResetSCs() {
	for TGT in "${TARGETS[@]}"; do
		printf "\nRUN: $TGT ${FUNCNAME[0]}\n"
		CMD="restart sc both"
		printf "  $CMD "
		DoCmd ${TGT} ${CMD} | jq -r '.status[]."response-type"'
	done
}
ResetMCs() {
	for TGT in "${TARGETS[@]}"; do
		printf "\nRUN: $TGT ${FUNCNAME[0]}\n"
		CMD="restart mc both"
		printf "  $CMD "
		DoCmd ${TGT} ${CMD} | jq -r '.status[]."response-type"'
	done
}


GetPowerReadings() {
	TGT=$1
	printf "\nRUN: ${FUNCNAME[0]}\n"
	printf "controller,\tL1_VOLT,\tL1_AMP,\tL1_WATT,\tL2_VOLT,\tL2_AMP,\tL2_WATT,\tTotalWatts\n"
	for TGT in ${TARGETS[*]}; do
		RESULT=$(ShowSensorStatusJSON $TGT)
		LVOLT1=$(echo ${RESULT} | jq -r '.sensors[]? | select(."durable-id" == "sensor_volt_psu_0.0.1").value')
		LVOLT2=$(echo ${RESULT} | jq -r '.sensors[]? | select(."durable-id" == "sensor_volt_psu_0.1.1").value')
		LCURR1=$(echo ${RESULT} | jq -r '.sensors[]? | select(."durable-id" == "sensor_curr_psu_0.0.1").value')
		LCURR2=$(echo ${RESULT} | jq -r '.sensors[]? | select(."durable-id" == "sensor_curr_psu_0.1.1").value')
		LWATT1=$(echo "scale=2; $LVOLT1 * $LCURR1" | bc -l)
		LWATT2=$(echo "scale=2; $LVOLT2 * $LCURR2" | bc -l)
		LWATT_TOTAL=$(echo "scale=2; $LWATT1 + $LWATT2" | bc -l)
		printf "$TGT,\t$LVOLT1,\t\t$LCURR1,\t$LWATT1,\t\t$LVOLT2,\t\t$LCURR2,\t$LWATT2,\t\t$LWATT_TOTAL\n"
	done
}
GetEcliKeyData() {
	TGT=$1
	printf "\nRUN: $TGT ${FUNCNAME[0]}\n"
	ShowConfigurationJSON $TGT | \
	 jq -r '(.versions[]? | ."object-name" + "   SC_Version: " + ."sc-fw" + "   MC_Version: " +."mc-fw"),(.controllers[]? | ."durable-id" + "_internal_serial_number: " + ."internal-serial-number")'
}

GetSasBaseInitiatorIDs() {
	for TGT in "${TARGETS[@]}"; do
	HNAME="$(uname -n  | cut -b 1-10)"
	printf "\nRUN: $TGT ${FUNCNAME[0]}\n"
	HBAs=$(ShowMpt3SasHBAsJSON)
	SAS_ADDRS=$(printf "$HBAs" | jq -r '.mpt3hba[]."sas-address"' | cut -c -15)
	echo "Gathering Initiators"
	RPT=$(ShowInitiatorsJSON $TGT)
	INITIATORS=$(printf "$RPT" | jq -r '.initiator[]? | select(.discovered == "Yes").id')
	echo "Recommendations:"
	for SAS_ADDR in ${SAS_ADDRS}
	do 
		#echo "Looking for HBA $SAS_ADDR"
		for INIT in $INITIATORS
		do
			#echo "$HBA $INIT"
			if grep -q "$SAS_ADDR" <<< "$INIT"; then
				CTLR_PORT="XX"
				A_CTRLR_PORT=$(printf "$RPT" | jq --arg I "${INIT}" -r '.initiator[]? | select((.discovered == "Yes") and .id == $I) | (."host-port-bits-a"| tostring)')
				B_CTRLR_PORT=$(printf "$RPT" | jq --arg I "${INIT}" -r '.initiator[]? | select((.discovered == "Yes") and .id == $I) | (."host-port-bits-b"| tostring)')
				if [[ ${A_CTRLR_PORT} != 0 ]] ; then
					CTRLR_PORT="A${A_CTRLR_PORT}"
				elif [[ ${B_CTRLR_PORT} != 0 ]] ; then
					CTRLR_PORT="B${B_CTRLR_PORT}"
				fi
				P=""
				PORT_IDX=$(echo $INIT | sed "s/$SAS_ADDR//g")
				#echo "PortIDX=$PORT_IDX"
				case $PORT_IDX in
				"0")
					P="0"
				;;
				"1")
					P="1"
				;;
				"8")
					P="2"
				;;
				"9")
					P="3"
				;;
				*)
					P="UNK"
				;;
				esac
				NICK_NAME=$(printf "$HBAs" \
					| jq --arg SAS_ADDR $SAS_ADDR --arg HNAME "${HNAME}" --arg PORT $P -r \
					'.mpt3hba[] | select (."sas-address" | contains($SAS_ADDR)) | $HNAME + "-" + ."board-name" + "-" + ."unique-id" + "-P" + $PORT')
				NICK_NAME="${NICK_NAME}${CTRLR_PORT}"
				printf "  export SSHPASS='${SSHPASS}'; sshpass -e ssh ${USER}@${TGT} 'set cli-parameters json; set initiator id $INIT nickname $NICK_NAME'\n"
			fi
		done
	done
	done
}
MapVolumes() {
	for TGT in "${TARGETS[@]}"; do
	HNAME="$(uname -n  | cut -b 1-10)"
	printf "\nRUN: $TGT ${FUNCNAME[0]}\n"
	HBAs=$(ShowMpt3SasHBAsJSON)
	SAS_ADDRS=$(printf "$HBAs" | jq -r '.mpt3hba[]."sas-address"' | cut -c -15)
	echo "Gathering Initiators"
	RPT=$(ShowInitiatorsJSON $TGT)
	INITIATORS=$(printf "$RPT" | jq -r '.initiator[]? | select(.discovered == "Yes").id')
	for SAS_ADDR in ${SAS_ADDRS}
	do 
		#echo "Looking for HBA $SAS_ADDR"
		for INIT in $INITIATORS
		do
			#echo "$HBA $INIT"
			if grep -q "$SAS_ADDR" <<< "$INIT"; then
				CTLR_PORT="XX"
				A_CTRLR_PORT=$(printf "$RPT" | jq --arg I "${INIT}" -r '.initiator[]? | select((.discovered == "Yes") and .id == $I) | (."host-port-bits-a"| tostring)')
				case $A_CTRLR_PORT in
				"1")
					A_CTRLR_PORT="a0"
				;;
				"2")
					A_CTRLR_PORT="a1"
				;;
				"4")
					A_CTRLR_PORT="a2"
				;;
				"8")
					A_CTRLR_PORT="a3"
				;;
				*)
					A_CTRLR_PORT=""
				;;
				esac
				B_CTRLR_PORT=$(printf "$RPT" | jq --arg I "${INIT}" -r '.initiator[]? | select((.discovered == "Yes") and .id == $I) | (."host-port-bits-b"| tostring)')
				case $B_CTRLR_PORT in
				"1")
					B_CTRLR_PORT="b0"
				;;
				"2")
					B_CTRLR_PORT="b1"
				;;
				"4")
					B_CTRLR_PORT="b2"
				;;
				"8")
					B_CTRLR_PORT="b3"
				;;
				*)
					B_CTRLR_PORT=""
				;;
				esac
				if [[ ${A_CTRLR_PORT} != "" ]] ; then
					CTRLR_PORT="${A_CTRLR_PORT}"
				elif [[ ${B_CTRLR_PORT} != "" ]] ; then
					CTRLR_PORT="${B_CTRLR_PORT}"
				fi
				P=""
				PORT_IDX=$(echo $INIT | sed "s/$SAS_ADDR//g")
				#echo "PortIDX=$PORT_IDX"
				case $PORT_IDX in
				"0")
					P="0"
				;;
				"1")
					P="1"
				;;
				"8")
					P="2"
				;;
				"9")
					P="3"
				;;
				*)
					P="U"
				;;
				esac
				NICK_NAME=$(printf "$HBAs" \
					| jq --arg SAS_ADDR $SAS_ADDR --arg HNAME "${HNAME}" --arg PORT $P -r \
					'.mpt3hba[] | select (."sas-address" | contains($SAS_ADDR)) | $HNAME + "-" + ."board-name" + "-" + ."unique-id" + "-P" + $PORT')
				NICK_NAME="${NICK_NAME}${CTRLR_PORT}"
				CMD="set initiator id $INIT nickname $NICK_NAME"
				printf "${TGT} ${CMD}  "
				DoCmd "${TGT}" "${CMD}" | jq -r '.status[]."response-type"'
				printf "\nGathering Volumes\n"
				VOLS="$(ShowVolumesJSON $TGT)"
				A_VOLS="$(echo $VOLS| jq -r '.volumes[]? | select(.owner == "A")."serial-number"')"
				B_VOLS="$(echo $VOLS| jq -r '.volumes[]? | select(.owner == "B")."serial-number"')"
				LUN=1
				for V in $A_VOLS; do
					if [ "$A_VOLS" != "" ] &&  [ "X${A_CTRLR_PORT}" != "X" ]; then
						#echo "A volume: $V LUN=$LUN"
						CMD="map volume $V ports ${CTRLR_PORT} initiator $NICK_NAME lun $LUN"
						printf "$CMD "
						DoCmd "$TGT" "$CMD" | jq -r '.status[]."response-type"'
						LUN=$((LUN+1))
					fi
				done
				wait
				LUN=1
				for V in $B_VOLS; do
					if [ "$B_VOLS" != "" ] && [ "X${B_CTRLR_PORT}" != "X" ]; then
						#echo "B volume: $V LUN=$LUN"
						CMD="map volume $V ports ${CTRLR_PORT} initiator $NICK_NAME lun $LUN"
						printf "$CMD "
						DoCmd "$TGT" "$CMD" | jq -r '.status[]."response-type"' 
						LUN=$((LUN+1))
					fi
				done
				wait
			fi
		done
	done
	done
}
Create_2DG_16plus2_ADAPT() {
	LUN_COUNT=${1:-1}
	printf "\nRUN: $TGT ${FUNCNAME[0]}\n"
	for TGT in ${TARGETS[*]}; do
		CMD="add disk-group"
		CMD="${CMD} type linear level adapt stripe-width 16+2 spare-capacity 20.0TiB interleaved-volume-count $LUN_COUNT"
		POOL1="assigned-to a disks 0.0-11,0.24-35,0.48-59,0.72-83,0.96-100 dg01"
		POOL2="assigned-to b disks 0.12-23,0.36-47,0.60-71,0.84-95,0.101-105 dg02"
		printf "${TGT} ${CMD} ${POOL1} "
		DoCmd ${TGT} ${CMD} ${POOL1} | jq -r '.status[]."response-type"'
		printf "${TGT} ${CMD} ${POOL2} "
		DoCmd ${TGT} ${CMD} ${POOL2} | jq -r '.status[]."response-type"'
	done
}
Create_4DG_8plus2_ADAPT() {
	LUN_COUNT=${1:-1}
	DG_COUNT=4
	LUN_COUNT=$((4 * DG_COUNT))
	printf "\nRUN: $TGT ${FUNCNAME[0]}\n"
	for TGT in ${TARGETS[*]}; do
		CMD="add disk-group"
		CMD="${CMD} type linear level adapt stripe-width 8+2 spare-capacity 10.0TiB interleaved-volume-count $LUN_COUNT interleaved-basename vol "
		DGS=("assigned-to a disks 0.0-11   dg01"\
		     "assigned-to a disks 0.12-23  dg02"\
		     "assigned-to a disks 0.24-35  dg03"\
		     "assigned-to a disks 0.36-47  dg04"\
		     "assigned-to b disks 0.53-64  dg05"\
		     "assigned-to b disks 0.65-76  dg06"\
		     "assigned-to b disks 0.77-88  dg07"\
		     "assigned-to b disks 0.89-100 dg08")
		for DG in "${DGS[@]}"
		do
			#echo ${TGT} ${CMD} ${DG}
			DoCmd ${TGT} ${CMD} ${DG} >/dev/null  #don't care about the output
		done
	done
}
Create_2DG_8plus2_ADAPT() {
	LUN_COUNT=${1:-1}
	printf "\nRUN: $TGT ${FUNCNAME[0]} with $LUN_COUNT luns.\n"
	for TGT in ${TARGETS[*]}; do
		CMD="add disk-group"
		CMD="${CMD} type linear level adapt stripe-width 8+2 spare-capacity 10.0TiB interleaved-volume-count $LUN_COUNT interleaved-basename vol "
		DGS=("assigned-to a disks 0.0-52   dg01"\
		     "assigned-to b disks 0.53-105 dg02")
		for DG in "${DGS[@]}"
		do
			DoCmd ${TGT} ${CMD} ${DG} >/dev/null #don't care about the output
		done
	done
}

ProvisionHighPerfBlock() {
	printf "\nRUN: ${FUNCNAME[0]}\n"
	RemoveAllInitiatorNickNames
	RemoveAllDiskGroupsFromAllControllers
	Create_2DG_8plus2_ADAPT 24
	MapVolumes
}
ProvisionForZFS() {
	printf "\nRUN: ${FUNCNAME[0]}\n"
	RemoveAllDiskGroupsFromAllControllers
	RemoveAllInitiatorNickNames
	Create_2DG_16plus2_ADAPT 1
	MapVolumes
}
GatherInfo() {
	LOG="cvt_config_$(date +"%F_%H-%M-%S")_$(uname -n).txt"
	LOG=$(echo ${LOG} | sed 's/ /_/g')
	for CMD in ShowMpt3SasHBAs GetInquiry GetPowerReadings GetVolumes GetInitiators GetMaps GetDiskGroups GetDisksInDiskGroups GetHostPhyStatistics GetDisks
	do
		$CMD | tee -a "${LOG}"
	done
}
GetInitiatorNaming() {
	LOG="cvt_initiators_$(date +"%F_%H-%M-%S")_$(uname -n).txt"
	LOG=$(echo ${LOG} | sed 's/ /_/g')
	for CMD in ShowMpt3SasHBAs GetInitiators GetMaps GetDiskGroups
	do
		$CMD | tee -a "${LOG}"
	done
}

Get_IPs (){
	if [ $(which sg_inq) ] ; then
		for SG_DEV in $(ls /dev/sg*)
		do
			sg_inq  ${SG_DEV}  | grep SEAGATE -a2 | grep -a1 6575 | grep S100 >/dev/null &&
				sg_inq ${SG_DEV} --vpd -p 0x85 | grep 'http' | tr -d ' '
		done | sort -u | sed 's|http://||g' | tr '\n' ' '
	elif [ $(which sdparm) ]; then
		for SG_DEV in $(sdparm /dev/sg* --inquiry -p 0 | grep -e 'SEAGATE.*6575' | sed 's/:.*$//g' | tr -d ' ')
		do
			sudo sdparm ${SG_DEV}  --inquiry -p 0x85 | grep http | sed 's/http:\/\///g' | tr -d ' '
		done | sort -u
	else
		echo "Please install either sg3-utils or sdparm to continue"
		exit 1
	fi
}
GetEnclosureInfo() {
	echo "Getting Enclosure IPs Serial Numbers" >&2
	echo "Iterating over IPs" >&2
	for IP in $(su root -c  "bash  $0 Get_IPs")
	do
		echo "Checking $IP" >&2
		CVT_CONFIG=$(ShowConfigurationJSON ${IP})
		A_HOSTNAME=$(echo "${CVT_CONFIG}" | jq -r '."mgmt-hostnames"[]? | select(.controller=="A")."mgmt-hostname"')
		B_HOSTNAME=$(echo "${CVT_CONFIG}" | jq -r '."mgmt-hostnames"[]? | select(.controller=="B")."mgmt-hostname"')
		echo "HOSTNAMES: $A_HOSTNAME $B_HOSTNAME"
		A_SERIAL=$(echo "$CVT_CONFIG" | jq -r '."controllers"[]? | select(.controller=="A")."serial-number"')
		B_SERIAL=$(echo "$CVT_CONFIG" | jq -r '."controllers"[]? | select(.controller=="B")."serial-number"')
		echo "SERIAL_NUMBERS: $A_SERIAL $B_SERIAL"
		A_IP="$(echo "$CVT_CONFIG" | jq -r '."controllers"[]? | select(."controller-id"=="A")."ip-address"')"
		B_IP="$(echo "$CVT_CONFIG" | jq -r '."controllers"[]? | select(."controller-id"=="B")."ip-address"')"
		SYS_NAME="$(echo "$CVT_CONFIG" | jq -r '."system"[]? | ."system-name"')"
		SYS_SERIAL="$(echo "$CVT_CONFIG" | jq -r '."system"[]? | ."midplane-serial-number"')"
		echo "$SYS_SERIAL $SYS_NAME controller_a $A_HOSTNAME $A_IP $A_SERIAL"
		echo "$SYS_SERIAL $SYS_NAME controller_b $B_HOSTNAME $B_IP $B_SERIAL"
	done | sort -u
}
#ShowMpt3SasHBAsJSON
#ShowMpt3SasHBAs
#ShowExpanderStatusStatsJSON corvault-1a
#GetExpanderStatusStats
#GetDisksInDiskGroups
#GetInitiatorNaming
#GetInitiators
#GetHostPhyStatistics
#GetVolumes
#GetSasBaseInitiatorIDs

#RemoveAllDiskGroupsFromAllControllers
#RemoveAllInitiatorNickNames
#CreateAllDiskGroupsOnAllControllers
#MapVolumes

#ResetHostSasLinks
#GatherInfo
#ResetSCs
#ResetMCs

ShowMenu() {
	cmd=(dialog --keep-tite --menu "Corvault Config Options:" 22 76 16)

	options=(1 "ProvisionHighPerfBlock"
		 2 "ProvisionForZFS"
		 3 "ShowMpt3SasHBAs"
		 4 "GatherInfo"
		 5 "GetExpanderStatusStats"
		 6 "GetEnclosureInfo"
		 7 "Get_IPs"
		 8 "GetDisksInDiskGroups"
		 9 "GetInitiators"
		 a "GetInitiatorNaming"
		 b "GetHostPhyStatistics"
		 c "GetVolumes"
		 d "GetSasBaseInitiatorIDs"
		 e "ResetHostSasLinks"
		 f "ResetSCs"
		 g "ResetMCs"
		 h "RemoveAllDiskGroupsFromAllControllers"
		 i "RemoveAllInitiatorNickNames"
		 j "MapVolumes"
		 x "Exit"
	 )

	while [ 1 ]
	do
		choices=$("${cmd[@]}" "${options[@]}" 2>&1>/dev/tty )
		for choice in $choices
		do
			case $choice in
			1)
				ProvisionHighPerfBlock
				;;
			2)
				ProvisionForZFS
				;;
			3)
				ShowMpt3SasHBAs
				;;
			4)
				GatherInfo
				;;
			5)
				GetExpanderStatusStats
				;;
			6)
				GetEnclosureInfo
				;;
			7)
				Get_IPs
				;;
			8)
				GetDisksInDiskGroups
				;;
			9)
				GetInitiators
				;;
			a)
				GetInitiatorNaming
				;;
			b)
				GetHostPhyStatistics
				;;
			c)
				GetVolumes
				;;
			d)
				GetSasBaseInitiatorIDs
				;;
			e)
				ResetHostSasLinks
				;;
			f)
				ResetSCs
				;;
			g)
				ResetMCs
				;;
			h)
				RemoveAllDiskGroupsFromAllControllers
				;;
			i)
				RemoveAllInitiatorNickNames
				;;
			j)
				MapVolumes
				;;
			*)
				echo "No selection"
				exit
				;;
			esac
			printf "\n"
			read -p "Hit enter to continue ..."
		done
	done
}

CheckForPreReqs

if [[ "${FUNCTION}"X == X ]] ; then
	ShowMenu
else
	#echo "Calling $FUNCTION $FUNPARAM" >&2
	$FUNCTION $FUNPARAM
fi
