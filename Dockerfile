FROM alpine

MAINTAINER Anthony Biondo <tonyb486@users.noreply.github.com>

RUN apk add --no-cache bash hostapd iptables dnsmasq docker iw chrony
ADD wlanstart.sh /bin/wlanstart.sh

ENTRYPOINT [ "/bin/wlanstart.sh" ]
