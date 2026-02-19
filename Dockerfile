FROM alpine

RUN apk add --no-cache hostapd iptables dnsmasq bash libcap net-tools supervisor
ADD wlanstart.sh /bin/wlanstart.sh
ADD supervisord.conf /etc/supervisord.conf

RUN addgroup -S alpine && adduser -S alpine -G alpine

## give permissions to these binaries to do networking things
RUN setcap cap_net_raw,cap_net_admin+ep /usr/sbin/hostapd && \
    setcap cap_net_raw,cap_net_admin+ep /sbin/ifconfig && \
    setcap cap_net_raw,cap_net_admin+ep /usr/sbin/xtables-nft-multi &&\
    setcap cap_net_raw,cap_net_bind_service,cap_net_admin+ep /usr/sbin/dnsmasq

## give user alpine permissions to the basic files it needs to play with
RUN touch /var/lib/misc/dnsmasq.leases && chown alpine /var/lib/misc/dnsmasq.leases && \
    touch /etc/dnsmasq.conf && chown alpine /etc/dnsmasq.conf && \
    touch /etc/hostapd.conf && chown alpine /etc/hostapd.conf && \
    touch /etc/ntp.conf && chown alpine /etc/ntp.conf

# supervisord stuff
RUN mkdir -p /run/supervisor && chown alpine /run/supervisor

# run as alpine
USER alpine
ENTRYPOINT [ "/bin/wlanstart.sh" ]
