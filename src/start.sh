#!/bin/bash
# Setting DBUS addresss so that we can talk to Modem Manager
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/host/run/dbus/system_bus_socket"

# Setup logging function
function log {
	if [[ "${CONSOLE_LOGGING}" == "1" ]]; then
		echo "[$(date --rfc-3339=seconds)]: $*" >>/data/soracom.log;
		echo "$*";
	else
    	echo "[$(date --rfc-3339=seconds)]: $*" >>/data/soracom.log;
    fi
}

# Check if CONSOLE_LOGGING is set, otherwise indicate that logging is going to /data/soracom.log
if [[ "${CONSOLE_LOGGING}" == "1" ]]; then
	echo "CONSOLE_LOGGING is set to 1, logging to console and /data/soracom.log"
else
	echo "CONSOLE_LOGGING isn't set to 1, logging to /data/soracom.log"
fi

# Start Linux watchdog
log "`service watchdog start`"

# Add Soracom Network Manager connection
log "`python soracom.py`"

# Check if we should disable non-cellular connectivity
if [[ -n "${CELLULAR_ONLY+x}" ]]; then
	log "Starting device in Cellular mode"
	ls /sys/class/net | grep -q wlan0
	if [[ $? -eq 0 ]]; then
		ifconfig wlan0 down
	fi
	ls /sys/class/net | grep -q eth0
	if [[ $? -eq 0 ]]; then
		ifconfig eth0 down
	fi
else
	ls /sys/class/net | grep -q wlan0
	if [[ $? -eq 0 ]]; then
		ifconfig wlan0 up
	fi
	ls /sys/class/net | grep -q eth0
	if [[ $? -eq 0 ]]; then
		ifconfig eth0 up
	fi
fi

# Operators scanning function, please note that GSM connection is disabled while scanning
# If there are no other connection, logs will not appear in Resin console but are available in /data/soracom.log
if [[ -n "${SCAN_OPERATORS+x}" ]]; then
	mmcli -L | grep -q Modem
	if [ $? -eq 0 ]; then
		MODEM_NUMBER=`mmcli -L | grep Modem | head -1 | sed -e 's/\//\ /g' | awk '{print $5}'`
		log "`python nmcli.py deactivate soracom`"
		log "`mmcli -m ${MODEM_NUMBER} --3gpp-scan --timeout=220`"
		log "`python nmcli.py activate soracom`"
	else
		log "No modem available, cannot scan avaialbe Operators"
	fi
fi

# Operator selection function
# It will mommentarily switch off soracom connection and make sure that operator is avaiable before trying to connect to it
# The Operator ID setting isn't persistent in the modem and will need to be re-added after a reboot/reset
if [[ -n "${OPERATOR_ID+x}" && ! -f /data/operator_setting_failed ]]; then
	mmcli -L | grep -q Modem
	if [ $? -eq 0 ]; then
		MODEM_NUMBER=`mmcli -L | grep Modem | head -1 | sed -e 's/\//\ /g' | awk '{print $5}'`
		# Check to see if we're already connected to preferred operator
		mmcli -m ${MODEM_NUMBER} | grep -q "operator id" | grep -q ${OPERATOR_ID}
		if [ $? -eq 0 ]; then
			log "Already connected to Operator ID ${OPERATOR_ID}, starting application"
		else
			log "`python nmcli.py deactivate soracom`"
			mmcli -m ${MODEM_NUMBER} --3gpp-scan --timeout=220 | grep -q ${OPERATOR_ID}
			if [ $? -eq 0 ]; then
				log "Setting preferred Operator ID to ${OPERATOR_ID}"
				log "`mmcli -m ${MODEM_NUMBER} --3gpp-register-in-operator=${OPERATOR_ID}`"
				if [ $? -eq 0 ]; then
					log "`Successfully set Operator ID to ${OPERATOR_ID}`"
				else
					log "`Couldn't set Operator ID to ${OPERATOR_ID}, rebooting node to use default operator`"
					touch /data/operator_setting_failed
					curl -X POST --header "Content-Type:application/json" "$RESIN_SUPERVISOR_ADDRESS/v1/reboot?apikey=$RESIN_SUPERVISOR_API_KEY"
				fi
			else
				log "not setting preferred Operator ID as ${OPERATOR_ID} isn't avialble"
			fi
			log "`python nmcli.py activate soracom`"
		fi
	else
		log "No modem available, cannot set Operator ID"
	fi
fi

# Cleanup of operator_setting_failed file so that OPERATOR_ID setting will be tested/added in following reboot
if [[ -f /data/operator_setting_failed ]]; then
	log "Erasing /data/operator_setting_failed"
	rm /data/operator_setting_failed
fi

# Run connection check script every 500 seconds
# If Cellular Mode wasn't working, the device will reboot every 15mins until it works
while :
do
	# If a mmcli compatible modem is present, log signal quality
	mmcli -L | grep -q Modem
	if [ $? -eq 0 ]; then
		MODEM_NUMBER=`mmcli -L | grep Modem | head -1 | sed -e 's/\//\ /g' | awk '{print $5}'`
		mmcli -m ${MODEM_NUMBER} | grep state | grep -q connected
		if [ $? -eq 0 ]; then
			# Log signal quality
			if [[ -n "${MODEM_NUMBER+x}" ]]; then
				log "`mmcli -m ${MODEM_NUMBER} | grep 'access tech' | sed -e \"s/'//g\" | sed -e \"s/|//g\" | sed -e \":a;s/^\([[:space:]]*\)[[:space:]]//g\"`"
				log "`mmcli -m ${MODEM_NUMBER} | grep 'operator name' | sed -e \"s/'//g\" | sed -e \"s/|//g\" | sed -e ':a;s/^\([[:space:]]*\)[[:space:]]//g'`"
				log "`mmcli -m ${MODEM_NUMBER} | grep quality | sed -e \"s/'//g\" | awk '{print $2 " " $3 " " $4}'`%"
				log "`mmcli -m ${MODEM_NUMBER} --command='AT+CSQ'`"
			fi
		fi
	fi
	sleep 500;
	# Rotate log files
	log "`logrotate /usr/src/app/logrotate.conf`"
	# Check if internet connectivity is working, reboot if it isn't
	log "`/usr/src/app/reconnect.sh`"
done
