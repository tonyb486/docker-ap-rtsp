FROM alpine

RUN apk add --no-cache hostapd iptables dnsmasq bash
ADD wlanstart.sh /bin/wlanstart.sh

ENTRYPOINT [ "/bin/wlanstart.sh" ]
