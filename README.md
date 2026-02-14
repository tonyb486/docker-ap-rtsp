# Docker container stack: hostap + dhcp server + RTSP tunnel

This container starts wireless access point (hostap) and dhcp server (dnsmasq) in a docker
container. It does not provide Internet access to connected devices. Instead, it provides
an ntp server (crony) and forwards outside ports to the camera to allow for RTSP access.

## Requirements

On the host system install required wifi drivers, then make sure your wifi adapter
supports AP mode:

```
# iw list
...
        Supported interface modes:
                 * IBSS
                 * managed
                 * AP
                 * AP/VLAN
                 * WDS
                 * monitor
                 * mesh point
...
```

Set country regulations, for example, for the U.S. set:

```
# iw reg set US
country US: DFS-FCC
	(902 - 904 @ 2), (N/A, 30), (N/A)
	(904 - 920 @ 16), (N/A, 30), (N/A)
	(920 - 928 @ 8), (N/A, 30), (N/A)
	(2400 - 2472 @ 40), (N/A, 30), (N/A)
	(5150 - 5250 @ 80), (N/A, 23), (N/A), AUTO-BW
	(5250 - 5350 @ 80), (N/A, 24), (0 ms), DFS, AUTO-BW
	(5470 - 5730 @ 160), (N/A, 24), (0 ms), DFS
	(5730 - 5850 @ 80), (N/A, 30), (N/A), AUTO-BW
	(5850 - 5895 @ 40), (N/A, 27), (N/A), NO-OUTDOOR, AUTO-BW, PASSIVE-SCAN
	(5925 - 7125 @ 320), (N/A, 12), (N/A), NO-OUTDOOR, PASSIVE-SCAN
	(57240 - 71000 @ 2160), (N/A, 40), (N/A)
```

## Build / run

This requires access to docker socket, so it can run a short lived
container that reattaches network interface to network namespace of this
container. This keeps the wireless device in the same namespace as
the wireguard interface.

There is a sample compose.yml included.

For CAM_MACS, provide a comma separated list of all camera MAC addresses.

```
services:
    docker-ap-rtsp:
        image: docker-ap-rtsp
        build: .
        cap_add:
            - NET_ADMIN
        environment:
            TZ: America/New_York
            INTERFACE: wlan0
            SSID: rtspcam
            CAM_MACS: {MACADDRESS},{MACADDRESS},{MACADDRESS}
            WPA_PASSPHRASE: {PASSWORD}
            CONTAINER_NAME: docker-ap-rtsp
            PUBLIC: false
        ports:
            - 19800-19899:19800-19899
            - 55400-55499:55400-55499
        privileged: true
        volumes:
            - /sys:/sys:rw
            - /var/run/docker.sock:/var/run/docker.sock:rw
```

The script forwards ports 198xx and 554xx to 1984 and 8554 on each.

You'll see this in the output for reference:

```
docker-ap-rtsp-1  | === Camera wyzecam0: MAC D0:3F:27:80:E7:FE Internal IP 192.168.254.10 RTSP 55400 RTC 19800
docker-ap-rtsp-1  | === Camera wyzecam1: MAC D0:3F:27:80:DA:98 Internal IP 192.168.254.11 RTSP 55401 RTC 19801
```

Configure your camera to provide RTSP on port 8554, and to use 192.168.254.1 as an NTP server.

I use wyze cameras with modified firmware for this.

## License

MIT

## Acknowledgments

Thanks to https://github.com/sdelrio/rpi-hostap and https://github.com/offlinehacker/docker-ap
for providing original implementation of a related idea, some of which is used here.
