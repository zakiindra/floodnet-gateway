:delay 60s

# Disable LTE interface completely
/interface lte
set [ find default-name=lte1 ] disabled=yes

# Set timezone to NY
/system clock
set time-zone-name=America/New_York

# Enable GPS
/system gps
set enabled=yes port=gps

# Set WiFi LED to light when device is connected to wlan1 (now client mode)
/system leds
add interface=wlan1 leds=user-led type=interface-status

# Set router name
/system identity
set name=floodnet-ltap-gw

# Create WAN interface list
/interface list
add name=WAN

# Add ether1 and wlan1 (WiFi client) to WAN interface list
/interface list member
add comment=defconf interface=ether1 list=WAN
add interface=wlan1 list=WAN

# Create LAN interface list for ethernet
/interface list
add name=LAN

# Add ether1 to LAN interface list (for local configuration access)
/interface list member
add interface=ether1 list=LAN

# Set google DNS servers
/ip dns
set allow-remote-requests=yes servers=8.8.8.8,8.8.4.4

# Setup Wi-Fi client connection to "xyz" network
/interface wireless security-profiles
add authentication-types=wpa2-psk mode=dynamic-keys name=xyz-wifi \
    wpa2-pre-shared-key="abc"

/interface wireless
set [ find default-name=wlan1 ] band=2ghz-b/g/n channel-width=20/40mhz-XX \
    country="united states" disabled=no distance=indoors frequency=auto \
    installation=outdoor mode=station ssid=xyz security-profile=xyz-wifi \
    wireless-protocol=802.11

# Create DHCP client for WiFi interface to get IP from "xyz" network
/ip dhcp-client
add interface=wlan1

# Create DHCP client for ethernet (for local configuration)
/ip dhcp-client
add interface=ether1

# Set USB type to allow use of mini PCIe cards and wait for bring-up
/system routerboard usb set type=mini-PCIe
:delay 10s

# Remove all existing LoRa servers
/lora servers
remove [find up-port="1700"]

# Add US TTN LoRa servers
/lora servers
add address=us.mikrotik.thethings.industries down-port=1700 name=TTN-US \
    up-port=1700
add address=nam1.cloud.thethings.industries down-port=1700 name=\
    "TTS Cloud (nam1)" up-port=1700
add address=nam1.cloud.thethings.network down-port=1700 name="TTN V3 (nam1)" \
    up-port=1700

# Set R11e-LR9 config and assign US TTN LoRa servers
/lora disable 0
:delay 10s
/lora
set 0 antenna=uFL disabled=no name="floodnet-ltap-gw-$[:put [/lora get 0 hardware-id]]" \
servers="TTN V3 (nam1),TTN-US,TTS Cloud (nam1)"

# Set internet detect on all interfaces
/interface detect-internet
set detect-interface-list=all internet-interface-list=all lan-interface-list=\
    all wan-interface-list=all

# Turn on DDNS for future use
/ip cloud
set ddns-enabled=yes

# Setup firewall filters
/ip firewall filter
add action=accept chain=input comment="Allow Remote Winbox" in-interface=\
    RemoteWinboxVPN4
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMP" protocol=icmp
add action=accept chain=input comment=\
    "defconf: accept to local loopback (for CAPsMAN)" dst-address=127.0.0.1
add action=accept chain=input comment="defconf: accept from ethernet (Winbox access)" \
    in-interface=ether1
add action=drop chain=input comment="defconf: drop all other input" \
    in-interface-list=WAN
add action=accept chain=forward comment="defconf: accept in ipsec policy" \
    ipsec-policy=in,ipsec
add action=accept chain=forward comment="defconf: accept out ipsec policy" \
    ipsec-policy=out,ipsec
add action=fasttrack-connection chain=forward comment="defconf: fasttrack" \
    connection-state=established,related hw-offload=yes
add action=accept chain=forward comment=\
    "defconf: accept established,related, untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid
add action=drop chain=forward comment=\
    "defconf: drop all from WAN not DSTNATed" connection-nat-state=!dstnat \
    connection-state=new in-interface-list=WAN

# Setup firewall NAT for WiFi client connection
/ip firewall nat
add action=masquerade chain=srcnat comment="defconf: masquerade" \
    ipsec-policy=out,none out-interface=wlan1

# Turn on general internet watchdog - reboots device if 8.8.8.8 is not accessible after 10 minutes
/system watchdog
set ping-start-after-boot=10m ping-timeout=10m watch-address=8.8.8.8

# Modified scheduler to check WiFi connection instead of ethernet/LTE
/system scheduler
add interval=1m name=wifi-check on-event=":delay 10s\r\
    \nif ([/ping 8.8.8.8 interface=wlan1 count=1]=0) do={\r\
    \n:log info \"WiFi lost internet connection\"\r\
    \n/interface wireless disable wlan1\r\
    \n:delay 5s\r\
    \n/interface wireless enable wlan1\r\
    \n} else={\r\
    \n:log info \"WiFi has internet connection\"\r\
    \n}" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=feb/13/2023 start-time=16:03:21

# Keep LoRa watchdog
add interval=10s name=lora_watchdog on-event="if (put [len [/lora print as-val\
    ue;]] < 1) do={/system routerboard usb set type=mini-PCIe; /system routerb\
    oard usb power-reset bus=0 duration=5s; /lora enable 0;} else={/lora enabl\
    e 0;}" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=oct/28/2022 start-time=10:05:42

# Set admin password
/user set admin password=<ADMIN-PASSWORD>
