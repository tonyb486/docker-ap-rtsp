#!/bin/bash -e

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Default values
true ${INTERFACE:=wlan0}
true ${SUBNET:=192.168.254.0}
true ${AP_ADDR:=192.168.254.1}
true ${SSID:=rtspcam}
true ${CHANNEL:=11}
true ${WPA_PASSPHRASE:=passw0rd}
true ${HW_MODE:=g}
true ${DRIVER:=nl80211}
true ${HT_CAPAB:=[HT40-][SHORT-GI-20][SHORT-GI-40]}
true ${CONTAINER_NAME:=hostapd}

echo "Waiting for wireless interface to be attached to container..."

until ifconfig ${INTERFACE} &>/dev/null; do
    sleep 1;
done

cat > "/etc/hostapd.conf" <<EOF
interface=${INTERFACE}
driver=${DRIVER}
ssid=${SSID}
hw_mode=${HW_MODE}
channel=${CHANNEL}
wpa=2
wpa_passphrase=${WPA_PASSPHRASE}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_ptk_rekey=600
ieee80211n=1
ht_capab=${HT_CAPAB}
wmm_enabled=1
EOF

# Set up the interface
echo "Configuring interface ${INTERFACE}..."
# note, we can't use ip because it drops capabilities. so we use net-tools
# from alpine, since we also can't give cap_net_admin to busybox.
# (see https://marcoguerri.github.io/2023/10/13/capabilities-and-docker.html)
ifconfig ${INTERFACE} ${AP_ADDR}/24 up

# DHCP
echo "Configuring DHCP server and port forwarding .."
echo "dhcp-range=${SUBNET::-1}101,${SUBNET::-1}150,255.255.255.0,6h" > /etc/dnsmasq.conf
echo "port=0" >> /etc/dnsmasq.conf

## Port forwarding to cameras
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

NUM=0
for CAM in ${CAM_MACS//,/ }
do
    IP=192.168.254.$((NUM+10))
    echo "dhcp-host=${CAM},${IP},CAM${NUcM}" >> /etc/dnsmasq.conf

    RTSP_PORT=$(printf '554%02d' ${NUM})
    RTC_PORT=$(printf '198%02d' ${NUM})
    iptables -t nat -A PREROUTING -p tcp --dport $RTC_PORT -j DNAT --to-destination ${IP}:80
    iptables -t nat -A PREROUTING -p tcp --dport $RTSP_PORT -j DNAT --to-destination ${IP}:554
    iptables -A FORWARD -p tcp -d ${IP} --dport 80 -j ACCEPT
    iptables -A FORWARD -p tcp -d ${IP} --dport 554 -j ACCEPT

    echo "=== Camera CAM$NUM: MAC $CAM Internal IP $IP RTSP $RTSP_PORT RTC $RTC_PORT"

    NUM=$(($NUM+1))
done

iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -P FORWARD DROP

# start tasks
/usr/bin/supervisord -c /etc/supervisord.conf &

function end() {
    echo "Shutting down..."
    supervisorctl -c /etc/supervisord.conf stop all
    pkill supervisord
    exit 0
}
trap end SIGINT SIGTERM

wait -n
