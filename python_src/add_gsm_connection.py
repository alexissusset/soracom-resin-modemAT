"""
Add a connection to NetworkManager. You do this by sending a dict to
AddConnection. The dict below was generated with n-m dump on an existing
connection and then anonymised
"""

import NetworkManager
import uuid

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