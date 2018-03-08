# Soracom's sample resin.io Application with Cellular modem AT commands support  
This sample Application demonstrates how to use Resin.io based App+Device to leverage Cellular modems which AT commands support  
This Application also provides ability to scan available operators and leverage modem manager to select a specific operator  
This has been tested on Raspberry Pi 3, Raspberry Pi Zero, Raspberry Pi B+ and Nvidia JETSON TX2. It has been designed to work on all current and future devices supported by resin.io  
  
# Notes  
This Application implements two methods to talking to Modem Manager and Network Manager on ResinOS.  
The first one uses mmcli command line interface which communicates through DBUS socket  
The second one is the python-networkmanager python package which lets you write python code to interact with Network Manager, we've published a sample connection-add script `soracom.py` together with this sample Application  
  
It is also important to note that we're using resin/python Docker container in this project, due to potential conflicts with udevd and Modem Manager, we keep udevd off in the container (through supplied `entry.sh`) which ensures highest level of ResinOS compatibility with Cellular modems  
Be sure to use the latest version of ResinOS in order to have full support of your preferred Hardware  
  
Not all Cellular modems let you run AT commands as some of them expose a NATed Ethernet interface rather than a serial interface that Modem Manager can interface with, we've tested the following Application with Huawei MS2131, MS2372, ME909, MU709 and Quectel EC21  


# Setup  
1. In order to use a 3G Dongle with ResinOS 2.x and Soracom, you will have two choices after creating your Resin.io based App+Device:  
    1. Start the device on WiFi or Ethernet and let the soracom.py script add the GSM connection in Network Manager for you
    1. Place the soracom GSM configuration file on your device's SD card in /system-connections/ using the following command: `cp soracom /Volume/resin-boot/system-connections/`  
  
1. In your resin.io Application, please make sure to set the following Fleet Configuration variables to ensure that your Cellular modem has enough power:  
    1. RESIN_HOST_CONFIG_max_usb_current = 1  
    1. RESIN_HOST_CONGIG_safe_mode_gpio = 4  
  
1.You can also add the following Fleet Configuration variable to save bandwidth when pushing updates to your container:
    1. RESIN_SUPERVISOR_DELTA = 1 
  
# Resin.io environment variables  
Our sample application uses environment variables to enable a couple of useful features which optimise bandwidth usage (Switch console logging on and off) and ensure Cellular based connectivity:
* CELLULAR_ONLY: This option disables WiFi and Ethernet to ensure that the device solely uses Cellular connection  
* CONSOLE_LOGGING: Set to 1 in order to get application logs in Resin.io device console, logs are always written to /data/soracom.log, keep if off in order to save on Cellular based bandwidth  
* SCAN_OPERATORS: Set to 1 in order to scan available operators  
* OPERATOR_ID: Set to your preferred Operator ID and your modem will check if it's available, try to switch to it, reboot the host to connect back to an available operator if there's an error  

# Running AT commands
Through ModemManager package, you can run AT commands on your Cellular modem.

To do so, we've set the following variable in our bashrc configuration which enables mmcli and python-networkmanager to communicate with ResinOS DBUS:  

`export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket`

With this in place, you can connect to resin remote Terminal (we recommend resin CLI with `resin ssh` command) and run AT commands as follow:

`mmcli -m 0 --command=ATCOMMAND`

For example, you could get your SIM card IMSI:

`mmcli -m 0 --command=AT+CIMI`

Likewise, if you would like to get a list of connected modem, you can run:

`mmcli -L`

Another usage example which we've added to our `start.sh` script is the `AT+CSQ` command which shows you your Cellular connection strength

`mmcli -m 0 --command=AT+CSQ`

The network RSSI (strength) can be read as follow:
-100 dBm or less: Unacceptable signal, check antenna connection
-99 dbm to -90 dBm: Weak signal 
-89 dbm to -70 dBm: Medium to high signal
-69 dBm or greater: Strong signal



# Credits  
Feel free to visit our [Soracom](https://www.soracom.io) website if you'd like to get your Sim card and Dongle as well as learn more about various IoT topics  
Dennis Kaarsemaker and his contributors for making the [python-networkmanager](https://github.com/seveas/python-networkmanager) library and code examples  
And thank you to the folks at [Resin.io](https://www.resin.io) for making their awesome platform  

  
![Soracom Developers](https://raw.githubusercontent.com/soracom/resin-rpi-demo/master/logo_developers_head.png)