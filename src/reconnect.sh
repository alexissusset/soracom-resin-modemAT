#!/bin/bash
# Script that tries to connect to google.com 
if curl -s --connect-timeout 52 http://google.com  > /dev/null; then
	echo "Internet connection is working"
else
    echo "Internet connection seems down, restarting device"
    # Reset USB power
    echo 0 > /sys/devices/platform/soc/3f980000.usb/buspower;
    sleep 5
    echo 1 > /sys/devices/platform/soc/3f980000.usb/buspower;
    sleep 5
	if [[ -n "${CELLULAR_ONLY}" ]]; then
		# Reset WiFi and Ethernet
		for interface in /sys/class/net/wlan*
		do
			[[ -e "${interface}" ]] || break # handle the case of no wlan interface
			ifconfig "${interface}" down
		done
		for interface in /sys/class/net/eth*
		do
			[[ -e "$interface" ]] || break # handle the case of no wlan interface
			ifconfig "${interface}" down
		done
		
		sleep 5
		for interface in /sys/class/net/wlan*
		do
			[[ -e "${interface}" ]] || break # handle the case of no wlan interface
			ifconfig "${interface}" up
		done
		for interface in /sys/class/net/eth*
		do
			[[ -e "${interface}" ]] || break # handle the case of no wlan interface
			ifconfig "${interface}" up
		done
		sleep 5
	fi
    # Resin SUPERVISOR call to reboot the device
    curl -X POST --header "Content-Type:application/json" "${RESIN_SUPERVISOR_ADDRESS}/v1/reboot?apikey=${RESIN_SUPERVISOR_API_KEY}"
fi
