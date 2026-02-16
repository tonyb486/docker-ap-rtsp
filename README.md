# Docker container stack: hostap + dhcp server + RTSP tunnel

This container starts wireless access point (hostap) and dhcp server (dnsmasq) in a docker
container. It does not provide Internet access to connected devices. Instead, it provides
an ntp server and forwards outside ports to the camera to allow for RTSP access.

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

This includes a compose.yml file, and is intended to be used with docker compose. It runs two containers, one is a short-lived container in privileged mode, the other is the main container in a private netns with CAP_NET_ADMIN. The main container runs unprivileged.

The short-lived container requires access to docker socket, so it can attach the wireless network interface to network namespace of this container. This keeps the wireless device in the container's network namespace, and lets us set up a firewall in there.

Create a file, rtsp.env, and add in your interface (e.g., wlan0), the SSID you want to use, the password for that SSID, and a list of MAC addresses.

```
TZ: America/New_York
INTERFACE: WIRELESS_DEVICE_NAME
SSID: rtspcam
CAM_MACS: MAC1,MAC2,...
WPA_PASSPHRASE: WIRELESS_PASSWORD
```

A sample, rtsp.env.sample, is provided containing the above.

The container forwards ports 198xx and 554xx to 80 and 554 on each of the cameras you have attached, based on their mac address order listed. So, for the first camera, port 55400 will go to port 554 on the camera, and port 19800 will go to 80 on the camera. For the second, port 55401 will go to port 554 on the camera, etc. This continues for as many as you list in the CAM_MACS.

You'll see this in the output for your reference:

```
=== Camera CAM0: MAC D0:3F:27:XX:XX:XX Internal IP 192.168.254.10 RTSP 55400 WEB 19800
=== Camera CAM1: MAC D0:3F:27:XX:XX:XX Internal IP 192.168.254.11 RTSP 55401 WEB 19801
```

These are the only port forwards.

Configure your camera to provide RTSP on port 554, and to use 192.168.254.1 as an NTP server, as the container also includes a basic ntp server to synchronize the clocks on your cameras with.

I use wyze cameras with OpenIPC for this.

## License

MIT

## Acknowledgments

Thanks to https://github.com/sdelrio/rpi-hostap and https://github.com/offlinehacker/docker-ap
for providing original implementation of a related idea, some of which is used here.

```

```
