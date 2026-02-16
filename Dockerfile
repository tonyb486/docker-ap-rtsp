FROM alpine

RUN apk add --no-cache hostapd iptables dnsmasq bash libcap net-tools
ADD wlanstart.sh /bin/wlanstart.sh

RUN addgroup -S alpine && adduser -S alpine -G alpine

## give permissions to these binaries to do networking things
RUN setcap cap_net_raw,cap_net_admin+eip /usr/sbin/hostapd
RUN setcap cap_net_raw,cap_net_admin+eip /sbin/ifconfig # (from net-tools, not busybox)
RUN setcap cap_net_raw,cap_net_admin+eip /usr/sbin/xtables-nft-multi
RUN setcap cap_net_raw,cap_net_bind_service,cap_net_admin+eip /usr/sbin/dnsmasq

## give user alpine permissions to the basic files it needs to play with
RUN touch /var/lib/misc/dnsmasq.leases && chown alpine /var/lib/misc/dnsmasq.leases
RUN touch /etc/dnsmasq.conf && chown alpine /etc/dnsmasq.conf
RUN touch /etc/hostapd.conf && chown alpine /etc/hostapd.conf
RUN touch /etc/ntp.conf && chown alpine /etc/ntp.conf

# run as alpine
USER alpine
ENTRYPOINT [ "/bin/wlanstart.sh" ]
