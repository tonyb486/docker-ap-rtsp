#!/bin/bash -e

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Check if running in privileged mode
if [ ! -w "/sys" ] ; then
    echo "[Error] Not running in privileged mode."
    exit 1
fi

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


CONTAINER_ID=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}")
echo "Attaching interface ${INTERFACE} to container ${CONTAINER_NAME} ${CONTAINER_ID}"

CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' ${CONTAINER_ID})
CONTAINER_IMAGE=$(docker inspect -f '{{.Config.Image}}' ${CONTAINER_ID})

docker run -t --privileged --net=host --pid=host --rm --entrypoint /bin/sh ${CONTAINER_IMAGE} -c "
    PHY=\$(echo phy\$(iw dev ${INTERFACE} info | grep wiphy | tr ' ' '\n' | tail -n 1))
    iw phy \$PHY set netns ${CONTAINER_PID}
"

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

# unblock wlan
rfkill unblock wlan

# Set up the interface
echo "Setting interface ${INTERFACE}"

# Setup interface
ip link set ${INTERFACE} up
ip addr flush dev ${INTERFACE}
ip addr add ${AP_ADDR}/24 dev ${INTERFACE}

###
###

if [ $PUBLIC == "true" ]; then

    echo "Setting iptables for outgoing traffic..."

    sysctl -w net.ipv4.ip_dynaddr=1
    sysctl -w net.ipv4.ip_forward=1

    iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -j MASQUERADE > /dev/null 2>&1 || true
    iptables -t nat -A POSTROUTING -s ${SUBNET}/24 -j MASQUERADE

    iptables -D FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
    iptables -A FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT

    iptables -D FORWARD -i ${INTERFACE} -j ACCEPT > /dev/null 2>&1 || true
    iptables -A FORWARD -i ${INTERFACE} -j ACCEPT

fi
###
###

# Set up DHCP
echo "Configuring DHCP server and port forwarding .."
echo "dhcp-range=${SUBNET::-1}101,${SUBNET::-1}150,255.255.255.0,6h" > /etc/dnsmasq.conf

## port forwarding to cameras
sysctl -w net.ipv4.ip_forward=1

echo "streams:" > /etc/go2rtc.yaml
NUM=0
for CAM in ${CAM_MACS//,/ }
do
    IP=192.168.254.$((NUM+10))
    echo "dhcp-host=${CAM},${IP},WYZECAM${NUcM}" >> /etc/dnsmasq.conf

    RTSP_PORT=$(printf '554%02d' ${NUM})
    RTC_PORT=$(printf '198%02d' ${NUM})
    iptables -t nat -A PREROUTING -p tcp --dport $RTC_PORT -j DNAT --to-destination ${IP}:1984
    iptables -t nat -A PREROUTING -p tcp --dport $RTSP_PORT -j DNAT --to-destination ${IP}:8554

    echo "=== Camera wyzecam$NUM: MAC $CAM Internal IP $IP RTSP $RTSP_PORT RTC $RTC_PORT"

    NUM=$(($NUM+1))
done

iptables -t nat -A POSTROUTING -j MASQUERADE

echo "Configuring NTP server .."
cat > /etc/chrony/chrony.conf <<EOF
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst
allow 192.168.254.0/24
local stratum 10
port 123
driftfile /var/lib/chrony/drift
logdir /var/log/chrony
makestep 1.0 3
EOF

echo "Starting NTP server ..."
chronyd -d &

echo "Starting DHCP server ..."
dnsmasq -d &

echo "Starting HostAP daemon ..."
/usr/sbin/hostapd /etc/hostapd.conf
