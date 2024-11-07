### I wrote this script for a very specific problem (presumably with my Fedora Network driver), but I attribute some fault to the responsible wifi
### I've had a problem with my dorm's wifi and my laptop. Every now and then (usually during heavy bandwidth usage on my side and with the vpn active, which I always have), the internet connection (wifi) would just stop working. The Network is still connected, but for example a ping would just not come back anymore, not even destination unreachable.
### just blank no response. There may be a better way to fix this, but this script just autoconnects again to the last wifi, and the previous vpn (assuming you only have one active in the Linux network manager). And of course the nmcli package is required

if [[ $(expr length + "$(whereis nmcli)") -lt 10 ]]; then
	echo -e "\033[0;31m Warning nmcli is not installed, please install and try again!\033[0m"
	exit 1
fi

# the ping interval (2 seconds in this case)
interval=5

# get the list of connections, and select the current wifi and vpn uuids
ssid=$(nmcli -t con show --active | grep -i wireless | cut -d: -f1)
uuid_vpn=$(nmcli -t con show --active | grep -i vpn | cut -d: -f2)
uuid_wifi=$(nmcli -t con show --active | grep "$ssid" | cut -d: -f2)

vpn_status=$(nmcli -t -f GENERAL.STATE con show $uuid_vpn | cut -d: -f2)

echo "current SSID: $ssid with uuid: $uuid_wifi"

if [[ $vpn_status == "activated" ]] ; then
	echo "current VPN: $(nmcli -t con show --active | grep $uuid_vpn | cut -d: -f1) with uuid: $uuid_vpn"
else
	echo $vpn_status
	echo -e "\033[0;31m Warning: You are not connected to a VPN!\033[0m"
fi

connected=false

echo "starting script, checking for connection every: $interval seconds"
while true; do
	ping=$(ping -c 1 -W $interval 1.1.1.1)
	output=$(echo "$ping" | grep "time=")
	# disconnect is detected when the ping packet doesn't return within a given time (in this case same as the ping interval)
	if [[ $(expr length + "$output") == 0 ]] && [[ $(expr length + "$(echo "$ping" | grep "time")") -gt 0 ]]; then
		connected=false
		echo "disconnect detected"
		
		available=$(nmcli -t -f active,ssid dev wifi | grep "$ssid")
		if [[ ${#available} == 0 ]]; then
			echo "Error whilst trying to reconnect, wifi not found anymore! aborting..."
			exit 1
		else
			if [[ $vpn_status == "activated" ]]; then
				nmcli con down $uuid_vpn
				nmcli con up $uuid_wifi
				nmcli con up $uuid_vpn
			else
				nmcli con up $uuid_wifi
			fi
			connected=true
		fi
	else
		if $connected ; then
			echo "Reconnected Successfully"
			notify-send "Reconnected sucessfully"
			connected=false
		fi
	fi
	sleep $interval
done
