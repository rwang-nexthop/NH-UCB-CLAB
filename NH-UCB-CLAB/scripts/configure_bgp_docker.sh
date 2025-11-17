#!/usr/bin/env bash

# Script to configure Nexthop.AI SONiC containers from scratch
# Configures interfaces, IP addresses, loopbacks, and BGP

set -e  # Exit on error

# Container names and their AS numbers
declare -A CONTAINERS
CONTAINERS["clab-nexthop-sonic-clos-spine1"]="65000"
CONTAINERS["clab-nexthop-sonic-clos-spine2"]="65000"
CONTAINERS["clab-nexthop-sonic-clos-leaf1"]="65101"
CONTAINERS["clab-nexthop-sonic-clos-leaf2"]="65102"

# Function to fix host default routes
fix_host_routes() {
    echo "Fixing host default routes..."

    # Host1: Remove mgmt route, add data network route
    docker exec clab-nexthop-sonic-clos-host1 ip route del default via 172.20.20.1 dev eth0 2>/dev/null || true
    docker exec clab-nexthop-sonic-clos-host1 ip route add default via 192.168.1.1 dev eth1 2>/dev/null || true

    # Host2: Remove mgmt route, add data network route
    docker exec clab-nexthop-sonic-clos-host2 ip route del default via 172.20.20.1 dev eth0 2>/dev/null || true
    docker exec clab-nexthop-sonic-clos-host2 ip route add default via 192.168.2.1 dev eth1 2>/dev/null || true

    echo "✓ Host routes configured"
}

# Function to bring up eth interfaces (containerlab links)
bring_up_eth_interfaces() {
    echo "Bringing up eth interfaces on all devices..."

    # Spine switches (eth1, eth2)
    docker exec clab-nexthop-sonic-clos-spine1 ip link set eth1 up
    docker exec clab-nexthop-sonic-clos-spine1 ip link set eth2 up
    docker exec clab-nexthop-sonic-clos-spine2 ip link set eth1 up
    docker exec clab-nexthop-sonic-clos-spine2 ip link set eth2 up

    # Leaf switches (eth1, eth2, eth3)
    docker exec clab-nexthop-sonic-clos-leaf1 ip link set eth1 up
    docker exec clab-nexthop-sonic-clos-leaf1 ip link set eth2 up
    docker exec clab-nexthop-sonic-clos-leaf1 ip link set eth3 up
    docker exec clab-nexthop-sonic-clos-leaf2 ip link set eth1 up
    docker exec clab-nexthop-sonic-clos-leaf2 ip link set eth2 up
    docker exec clab-nexthop-sonic-clos-leaf2 ip link set eth3 up

    echo "✓ All eth interfaces are up"
    sleep 2
}

# Generic function to configure interfaces on a device
configure_interfaces() {
    local container=$1
    local device_name=$2
    shift 2
    local interfaces=("$@")

    echo "Configuring interfaces on $device_name..."

    for iface_config in "${interfaces[@]}"; do
        IFS='|' read -r iface_name iface_ip <<< "$iface_config"
        docker exec $container config interface ip add "$iface_name" "$iface_ip" 2>/dev/null || true
        docker exec $container config interface startup "$iface_name" 2>/dev/null || true
    done

    echo "✓ Interfaces configured on $device_name"
}

# Function to enable bgpd daemon
enable_bgpd() {
    local container_name=$1
    echo "Enabling bgpd in $container_name..."

    docker exec $container_name sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
    docker exec $container_name service frr restart
    sleep 3
}

# Generic function to configure BGP
configure_bgp() {
    local container_name=$1
    local asn=$2
    local router_id=$3
    local network=$4
    shift 4
    local neighbors=("$@")

    echo "Configuring BGP on $container_name (AS $asn)..."

    # Build vtysh commands
    local cmds=("configure terminal" "router bgp $asn" "bgp router-id $router_id"
                "bgp log-neighbor-changes" "no bgp ebgp-requires-policy")

    # Add neighbor definitions
    for neighbor_config in "${neighbors[@]}"; do
        IFS=',' read -r neighbor_ip neighbor_asn <<< "$neighbor_config"
        cmds+=("neighbor $neighbor_ip remote-as $neighbor_asn")
    done

    # Add address-family configuration
    cmds+=("address-family ipv4 unicast")
    [ -n "$network" ] && cmds+=("network $network")

    # Activate neighbors
    for neighbor_config in "${neighbors[@]}"; do
        IFS=',' read -r neighbor_ip _ <<< "$neighbor_config"
        cmds+=("neighbor $neighbor_ip activate")
    done

    cmds+=("redistribute connected" "exit-address-family" "exit")

    # Execute all commands
    local cmd_str=""
    for cmd in "${cmds[@]}"; do
        cmd_str="$cmd_str -c \"$cmd\""
    done

    eval "docker exec $container_name vtysh $cmd_str" 2>&1 | grep -v "Unknown command" || true

    # Save configuration
    docker exec $container_name vtysh -c "write memory" 2>/dev/null || \
    docker exec $container_name vtysh -c "write" 2>/dev/null || true

    echo "✓ Successfully configured $container_name"
}

# Main script
echo "=========================================="
echo "SONiC CLOS Lab - Complete Configuration"
echo "=========================================="
echo ""

# Step 0: Bring up eth interfaces
echo "Step 0: Bringing up containerlab eth interfaces..."
echo "---------------------------------------------------"
bring_up_eth_interfaces
echo ""

# Step 0.5: Fix host default routes
echo "Step 0.5: Configuring host routes..."
echo "-------------------------------------"
fix_host_routes
echo ""

# Step 1: Configure interfaces and IP addresses
echo "Step 1: Configuring interfaces and IP addresses..."
echo "---------------------------------------------------"

# Spine1 interfaces
configure_interfaces "clab-nexthop-sonic-clos-spine1" "spine1" \
    "Ethernet0|10.0.1.0/31" "Ethernet4|10.0.2.0/31" "Loopback0|1.1.1.1/32"

# Spine2 interfaces
configure_interfaces "clab-nexthop-sonic-clos-spine2" "spine2" \
    "Ethernet0|10.0.1.2/31" "Ethernet4|10.0.2.2/31" "Loopback0|2.2.2.2/32"

# Leaf1 interfaces
configure_interfaces "clab-nexthop-sonic-clos-leaf1" "leaf1" \
    "Ethernet0|10.0.1.1/31" "Ethernet4|10.0.1.3/31" "Ethernet8|192.168.1.1/24" "Loopback0|11.11.11.11/32"

# Leaf2 interfaces
configure_interfaces "clab-nexthop-sonic-clos-leaf2" "leaf2" \
    "Ethernet0|10.0.2.1/31" "Ethernet4|10.0.2.3/31" "Ethernet8|192.168.2.1/24" "Loopback0|22.22.22.22/32"

echo ""
sleep 5

# Step 2: Verify interface configuration
echo "Step 2: Verifying interface configuration..."
echo "---------------------------------------------"
for container in "${!CONTAINERS[@]}"; do
    echo "=== $container interfaces ==="
    docker exec $container show ip interface brief 2>/dev/null || docker exec $container ip addr show | grep -E "inet |^[0-9]"
    echo ""
done
sleep 2

# Step 3: Enable bgpd on all containers
echo "Step 3: Enabling bgpd daemon on all containers..."
echo "--------------------------------------------------"
for container in "${!CONTAINERS[@]}"; do
    enable_bgpd "$container"
done
echo ""

# Step 4: Configure BGP on spines
echo "Step 4: Configuring BGP on spine routers..."
echo "--------------------------------------------"
configure_bgp "clab-nexthop-sonic-clos-spine1" "65000" "1.1.1.1" "" \
    "10.0.1.1,65101" "10.0.2.1,65102"
configure_bgp "clab-nexthop-sonic-clos-spine2" "65000" "2.2.2.2" "" \
    "10.0.1.3,65101" "10.0.2.3,65102"
echo ""

# Step 5: Configure BGP on leaves
echo "Step 5: Configuring BGP on leaf routers..."
echo "-------------------------------------------"
configure_bgp "clab-nexthop-sonic-clos-leaf1" "65101" "11.11.11.11" "192.168.1.0/24" \
    "10.0.1.0,65000" "10.0.1.2,65000"
configure_bgp "clab-nexthop-sonic-clos-leaf2" "65102" "22.22.22.22" "192.168.2.0/24" \
    "10.0.2.0,65000" "10.0.2.2,65000"
echo ""

# Step 6: Wait for BGP to establish
echo "Step 6: Waiting for BGP sessions to establish..."
echo "-------------------------------------------------"
echo "Waiting 30 seconds..."
sleep 30

# Step 7: Verify BGP status
echo ""
echo "Step 7: Verifying BGP configuration..."
echo "---------------------------------------"
for container in "${!CONTAINERS[@]}"; do
    echo "=== $container BGP Summary ==="
    docker exec $container vtysh -c "show ip bgp summary"
    echo ""
done

# Step 8: Check connectivity
echo "Step 8: Testing connectivity..."
echo "--------------------------------"
echo "Testing host1 -> host2 connectivity..."
docker exec clab-nexthop-sonic-clos-host1 ping -c 3 192.168.2.10
echo ""
echo "Testing host2 -> host1 connectivity..."
docker exec clab-nexthop-sonic-clos-host2 ping -c 3 192.168.1.10
echo ""

echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "Verification commands:"
echo "  - Check BGP neighbors: docker exec <container> vtysh -c 'show ip bgp summary'"
echo "  - Check BGP routes:    docker exec <container> vtysh -c 'show ip bgp'"
echo "  - Check routing table: docker exec <container> vtysh -c 'show ip route'"
echo "  - Test connectivity:   docker exec clab-nexthop-sonic-clos-host1 ping 192.168.2.10"
echo ""
echo "Troubleshooting:"
echo "  - Check interfaces:    docker exec <container> show ip interface"
echo "  - Check FRR status:    docker exec <container> service frr status"
echo "  - Enter vtysh:         docker exec -it <container> vtysh"
echo ""
echo "Powered by Nexthop.AI"
echo ""

