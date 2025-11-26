#!/usr/bin/env bash

# Script to check BGP configuration and status on all SONiC containers

set -e

# Container names
CONTAINERS=(
    "clab-nexthop-sonic-clos-spine1"
    "clab-nexthop-sonic-clos-spine2"
    "clab-nexthop-sonic-clos-leaf1"
    "clab-nexthop-sonic-clos-leaf2"
)

echo "=========================================="
echo "BGP Configuration Check"
echo "=========================================="
echo ""

# Function to check BGP status
check_bgp_status() {
    local container=$1
    echo "=== $container ==="
    echo ""
    
    echo "1. BGP Summary:"
    docker exec $container vtysh -c "show ip bgp summary" 2>/dev/null || echo "  (BGP not running)"
    echo ""
    
    echo "2. BGP Neighbors:"
    docker exec $container vtysh -c "show ip bgp neighbors" 2>/dev/null || echo "  (No neighbors)"
    echo ""
    
    echo "3. BGP Routes:"
    docker exec $container vtysh -c "show ip bgp" 2>/dev/null || echo "  (No routes)"
    echo ""
    
    echo "4. Routing Table:"
    docker exec $container vtysh -c "show ip route" 2>/dev/null || echo "  (No routes)"
    echo ""
    
    echo "5. BGP Configuration:"
    docker exec $container vtysh -c "show running-config router bgp" 2>/dev/null || echo "  (No BGP config)"
    echo ""
    
    echo "6. Interface Status:"
    docker exec $container show ip interface brief 2>/dev/null || docker exec $container ip addr show | grep -E "inet |^[0-9]"
    echo ""
    echo "---"
    echo ""
}

# Check all containers
for container in "${CONTAINERS[@]}"; do
    check_bgp_status "$container"
done

echo "=========================================="
echo "Quick Verification Commands:"
echo "=========================================="
echo ""
echo "Check specific container BGP:"
echo "  docker exec clab-nexthop-sonic-clos-spine1 vtysh -c 'show ip bgp summary'"
echo ""
echo "Check BGP neighbors in detail:"
echo "  docker exec clab-nexthop-sonic-clos-spine1 vtysh -c 'show ip bgp neighbors'"
echo ""
echo "Check routing table:"
echo "  docker exec clab-nexthop-sonic-clos-leaf1 vtysh -c 'show ip route'"
echo ""
echo "Enter interactive vtysh shell:"
echo "  docker exec -it clab-nexthop-sonic-clos-spine1 vtysh"
echo ""
echo "Check FRR daemon status:"
echo "  docker exec clab-nexthop-sonic-clos-spine1 service frr status"
echo ""
echo "Check interfaces:"
echo "  docker exec clab-nexthop-sonic-clos-spine1 show ip interface"
echo ""

