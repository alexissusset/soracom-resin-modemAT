"""
List devices as well as existing and active connections
"""

import NetworkManager
c = NetworkManager.const

print("Available network devices")
print("%-10s %-19s %-20s %s" % ("Name", "State", "Driver", "Managed?"))
for dev in NetworkManager.NetworkManager.GetDevices():
    print("%-10s %-19s %-20s %s" % (dev.Interface, c('device_state', dev.State), dev.Driver, dev.Managed))

print("")

print("Available connections")
print("%-30s %s" % ("Name", "Type"))
for conn in NetworkManager.Settings.ListConnections():
    settings = conn.GetSettings()['connection']
    print("%-30s %s" % (settings['id'], settings['type']))

print("")

print("Active connections")
print("%-30s %-20s %-10s %s" % ("Name", "Type", "Default", "Devices"))
for conn in NetworkManager.NetworkManager.ActiveConnections:
    settings = conn.Connection.GetSettings()['connection']
    print("%-30s %-20s %-10s %s" % (settings['id'], settings['type'], conn.Default, ", ".join([x.Interface for x in conn.Devices])))