"""
Script that checks if Soracom network connection is present
If not, it will add it and reboot the device
"""

import NetworkManager
import uuid
import sys
import requests
from os import getenv

# Check to see if there's already a Soracom or GSM connection, exit if there is
for conn in NetworkManager.Settings.ListConnections():
    settings = conn.GetSettings()['connection']
    if settings['id'] == 'soracom':
    	print("Soracom connection already exists, starting main Application")
    	sys.exit()
    if settings['type'] == 'gsm':
    	print("Soracom connection already exists, starting main Application")
    	sys.exit()    

# Add Soracom connection
soracom_connection = {
	'connection': {
		'id': 'soracom',
		'type': 'gsm',
		'uuid': str(uuid.uuid4())
	},
	'gsm': {
		'apn': 'soracom.io',
		'number': '*99***1#'
	},
	'ipv4': {'method': 'auto'},
    'ipv6': {'method': 'auto'}
}

NetworkManager.Settings.AddConnection(soracom_connection)

# Connection has been added, reboot node to reset GSM Modem and establish connection
print("Soracom connection successfully added, rebooting to reset GSM Modem and establish connection")
url = "{0}/v1/reboot?apikey=".format(getenv('RESIN_SUPERVISOR_ADDRESS')) + "{0}".format(getenv('RESIN_SUPERVISOR_API_KEY'))
requests.post(url)
