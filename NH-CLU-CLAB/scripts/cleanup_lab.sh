#!/usr/bin/env bash

# Script to cleanly destroy the Nexthop.AI SONiC CLOS lab
# Stops all containers, removes networks, and cleans up artifacts

set -e

TOPOLOGY_FILE="../topology/nexthop-sonic-clos.clab.yml"
LAB_NAME="nexthop-sonic-clos"

echo "=========================================="
echo "Nexthop.AI - SONiC CLOS Lab Cleanup"
echo "=========================================="
echo ""

# Check if we're in the scripts directory
if [ ! -f "$TOPOLOGY_FILE" ]; then
    echo "Error: Topology file not found at $TOPOLOGY_FILE"
    echo "Please run this script from the scripts/ directory"
    exit 1
fi

# Step 1: Destroy the containerlab topology
echo "Step 1: Destroying containerlab topology..."
echo "--------------------------------------------"
cd ../topology
if clab inspect -t nexthop-sonic-clos.clab.yml &>/dev/null; then
    echo "Lab is running, destroying..."
    clab destroy -t nexthop-sonic-clos.clab.yml --cleanup
    echo "✓ Lab destroyed"
else
    echo "Lab is not running, skipping destroy"
fi
cd ../scripts
echo ""

# Step 2: Remove any orphaned containers
echo "Step 2: Removing orphaned containers..."
echo "----------------------------------------"
ORPHANED=$(docker ps -a --filter "name=clab-$LAB_NAME" --format "{{.Names}}" 2>/dev/null || true)
if [ -n "$ORPHANED" ]; then
    echo "Found orphaned containers:"
    echo "$ORPHANED"
    docker rm -f $ORPHANED 2>/dev/null || true
    echo "✓ Orphaned containers removed"
else
    echo "No orphaned containers found"
fi
echo ""

# Step 3: Remove orphaned networks
echo "Step 3: Removing orphaned networks..."
echo "--------------------------------------"
ORPHANED_NETS=$(docker network ls --filter "name=clab" --format "{{.Name}}" 2>/dev/null || true)
if [ -n "$ORPHANED_NETS" ]; then
    echo "Found orphaned networks:"
    echo "$ORPHANED_NETS"
    for net in $ORPHANED_NETS; do
        docker network rm "$net" 2>/dev/null || echo "  Could not remove $net (may be in use)"
    done
    echo "✓ Orphaned networks cleaned"
else
    echo "No orphaned networks found"
fi
echo ""

# Step 4: Clean up lab directory artifacts
echo "Step 4: Cleaning up lab artifacts..."
echo "-------------------------------------"
if [ -d "../topology/clab-$LAB_NAME" ]; then
    echo "Removing lab directory: topology/clab-$LAB_NAME"
    rm -rf "../topology/clab-$LAB_NAME"
    echo "✓ Lab directory removed"
else
    echo "No lab directory found"
fi
echo ""

# Step 5: Remove SSH config entries
echo "Step 5: Cleaning up SSH config..."
echo "----------------------------------"
SSH_CONFIG="/etc/ssh/ssh_config.d/clab-$LAB_NAME.conf"
if [ -f "$SSH_CONFIG" ]; then
    echo "Removing SSH config: $SSH_CONFIG"
    sudo rm -f "$SSH_CONFIG" 2>/dev/null || echo "  Could not remove (may need sudo)"
    echo "✓ SSH config removed"
else
    echo "No SSH config found"
fi
echo ""

# Step 6: Clean up /etc/hosts entries
echo "Step 6: Cleaning up /etc/hosts entries..."
echo "------------------------------------------"
if grep -q "clab-$LAB_NAME" /etc/hosts 2>/dev/null; then
    echo "Found containerlab entries in /etc/hosts"
    echo "Note: You may need to manually remove these entries with sudo"
    echo "  sudo sed -i '/clab-$LAB_NAME/d' /etc/hosts"
else
    echo "No /etc/hosts entries found"
fi
echo ""

# Step 7: Verify cleanup
echo "Step 7: Verifying cleanup..."
echo "----------------------------"
REMAINING_CONTAINERS=$(docker ps -a --filter "name=clab-$LAB_NAME" --format "{{.Names}}" 2>/dev/null || true)
REMAINING_NETWORKS=$(docker network ls --filter "name=clab" --format "{{.Name}}" 2>/dev/null || true)

if [ -z "$REMAINING_CONTAINERS" ] && [ -z "$REMAINING_NETWORKS" ]; then
    echo "✓ Cleanup complete! No containers or networks remaining."
else
    echo "⚠ Warning: Some resources may still exist:"
    [ -n "$REMAINING_CONTAINERS" ] && echo "  Containers: $REMAINING_CONTAINERS"
    [ -n "$REMAINING_NETWORKS" ] && echo "  Networks: $REMAINING_NETWORKS"
fi
echo ""

echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "To redeploy the lab, run:"
echo "  cd scripts"
echo "  ./deploy_lab.sh"
echo ""
echo "Or manually:"
echo "  cd topology"
echo "  clab deploy -t nexthop-sonic-clos.clab.yml"
echo "  cd ../scripts"
echo "  ./configure_bgp_docker.sh"
echo ""
echo "Powered by Nexthop.AI"
echo ""

