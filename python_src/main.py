"""
Main script that checks GSM Signal strength and posts it to Soracom Harvest
|| For now, prints active connections
"""

import NetworkManager
import requests

c = NetworkManager.const

for conn in NetworkManager.NetworkManager.ActiveConnections:
    settings = conn.Connection.GetSettings()

    for s in list(settings.keys()):
        if 'data' in settings[s]:
            settings[s + '-data'] = settings[s].pop('data')

    secrets = conn.Connection.GetSecrets()
    for key in secrets:
        settings[key].update(secrets[key])

    devices = ""
    if conn.Devices:
        devices = " (on %s)" % ", ".join([x.Interface for x in conn.Devices])
    print("Active connection: %s%s" % (settings['connection']['id'], devices))