#!/bin/bash
# Setting DBUS addresss so that we can talk to Modem Manager
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/host/run/dbus/system_bus_socket"

# Setup logging function
function log {
	if [[ "${CONSOLE_LOGGING}" == "0" ]]; then
		echo "[$(date --rfc-3339=seconds)]: $*" >>/data/soracom.log;
	else
    	echo "[$(date --rfc-3339=seconds)]: $*" >>/data/soracom.log;
		echo "$*";
    fi
}

# Check if CONSOLE_LOGGING is set, otherwise indicate that logging is going to /data/soracom.log
if [[ "${CONSOLE_LOGGING}" == "1" ]]; then
	echo "CONSOLE_LOGGING is set to 1, logging to console and /data/soracom.log"
else
	echo "CONSOLE_LOGGING isn't set to 1, logging to /data/soracom.log"
fi

# Start Linux watchdog
log "$(service watchdog start)"

# Add Soracom Network Manager connection
log "$(python soracom.py)"

# Check if we should disable non-cellular connectivity
if [[ -n "${CELLULAR_ONLY+x}" ]]; then
	log "Starting device in Cellular mode"
	for interface in /sys/class/net/wlan*
	do
		[[ -e "${interface}" ]] || break # handle the case of no wlan interface
		ifconfig "${interface}" down
	done
	for interface in /sys/class/net/eth*
	do
		[[ -e "$interface" ]] || break # handle the case of no ethernet interface
		ifconfig "${interface}" down
	done
else
	for interface in /sys/class/net/wlan*
	do
		[[ -e "${interface}" ]] || break # handle the case of no wlan interface
		ifconfig "${interface}" up
	done
	for interface in /sys/class/net/eth*
	do
		[[ -e "$interface" ]] || break # handle the case of no ethernet interface
		ifconfig "${interface}" up
	done
fi

# Operators scanning function, please note that GSM connection is disabled while scanning
# If there are no other connection, logs will not appear in Resin console but are available in /data/soracom.log
if [[ -n "${SCAN_OPERATORS+x}" ]]; then
	if mmcli -L | grep -q Modem; then
		MODEM_NUMBER=$(mmcli -L | grep Modem | head -1 | sed -e 's/\//\ /g' | awk '{print $5}')
		log "$(python nmcli.py deactivate soracom)"
		sleep 25
		log "$(mmcli -m "${MODEM_NUMBER}" --3gpp-scan --timeout=220)"
		log "$(python nmcli.py activate soracom)"
	else
		log "No modem available, cannot scan avaialbe Operators"
	fi
fi

# Operator selection function
# It will mommentarily switch off soracom connection and make sure that operator is avaiable before trying to connect to it
# The Operator ID setting isn't persistent in the modem and will need to be re-added after a reboot/reset
if [[ -n "${OPERATOR_ID+x}" && ! -f /data/operator_setting_failed ]]; then
	if mmcli -L | grep -q Modem; then
		MODEM_NUMBER=$(mmcli -L | grep Modem | head -1 | sed -e 's/\//\ /g' | awk '{print $5}')
		# Check to see if we're already connected to preferred operator
		if mmcli -m "${MODEM_NUMBER}" | grep -q "operator id" | grep -q "${OPERATOR_ID}"; then
			log "Already connected to Operator ID ${OPERATOR_ID}, starting application"
		else
			log "$(python nmcli.py deactivate soracom)"
			sleep 25
			if mmcli -m "${MODEM_NUMBER}" --3gpp-scan --timeout=220 | grep -q "${OPERATOR_ID}"; then
				log "Setting preferred Operator ID to ${OPERATOR_ID}"
				if mmcli -m "${MODEM_NUMBER}" --3gpp-register-in-operator="${OPERATOR_ID}"; then
					log "Successfully set Operator ID to ${OPERATOR_ID}"
				else
					log "Couldn't set Operator ID to ${OPERATOR_ID}, rebooting node to use default operator"
					touch /data/operator_setting_failed
					log "$(python nmcli.py activate soracom)"
					curl -X POST --header "Content-Type:application/json" "${RESIN_SUPERVISOR_ADDRESS}/v1/reboot?apikey=${RESIN_SUPERVISOR_API_KEY}"
				fi
			else
				log "not setting preferred Operator ID as ${OPERATOR_ID} isn't available"
			fi
			log "$(python nmcli.py activate soracom)"
		fi
	else
		log "No modem available, cannot set Operator ID"
	fi
fi

# Cleanup of operator_setting_failed file so that OPERATOR_ID setting will be tested/added in following reboot
if [[ -f /data/operator_setting_failed ]]; then
	log "Erasing /data/operator_setting_failed"
	log "$(rm /data/operator_setting_failed)"
fi

# Run connection check script every 500 seconds
# If Cellular Mode wasn't working, the device will reboot every 15mins until it works
while :
do
	# If a mmcli compatible modem is present, log signal quality
	if mmcli -L | grep -q Modem; then
		# Assign Modem number variable
		MODEM_NUMBER=$(mmcli -L | grep Modem | head -1 | sed -e 's/\//\ /g' | awk '{print $5}')
		if mmcli -m "${MODEM_NUMBER}" | grep state | grep -q connected; then
			if mmcli -m "${MODEM_NUMBER}" | grep state | grep -q connected; then
				# Log signal quality
				log "$(mmcli -m "${MODEM_NUMBER}" | grep 'access tech' | tr -d \' | sed -e 's/|//g' | sed -e ':a;s/^\([[:space:]]*\)[[:space:]]//g' 2>&1)"
				log "$(mmcli -m "${MODEM_NUMBER}" | grep 'operator name' | tr -d \' | sed -e 's/|//g' | sed -e ':a;s/^\([[:space:]]*\)[[:space:]]//g' 2>&1)"
				log "$(mmcli -m "${MODEM_NUMBER}" | grep quality | tr -d \' | awk '{print $2 " " $3 " " $4}' 2>&1)"
				log "$(mmcli -m "${MODEM_NUMBER}" --command='AT+CSQ')"
			fi
		fi
	fi
	sleep 500;
	# Rotate log files
	log "$(logrotate /usr/src/app/logrotate.conf)"
	# Check if internet connectivity is working, reboot if it isn't
	log "$(/usr/src/app/reconnect.sh)"
done
