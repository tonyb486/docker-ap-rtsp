#!/bin/bash -e

echo "Attaching $INTERFACE to $TARGET_CONTAINER..."

CONTAINER_PID=$(docker container inspect -f '{{.State.Pid}}' $TARGET_CONTAINER)
NETNS=$(ip netns identify $CONTAINER_PID)
PHY="phy"$(iw dev $INTERFACE info | grep wiphy | awk '{print $2}')

echo "Moving $PHY to netns $NETNS..."
iw phy $PHY set netns $CONTAINER_PID

echo "Enabling IP forwarding..."
ip netns exec $NETNS sysctl -w net.ipv4.ip_forward=1

echo "Disabling rfkill..."
ip netns exec $NETNS rfkill unblock wlan

echo 'Done!'
