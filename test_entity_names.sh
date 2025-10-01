#!/bin/bash

# Test the entity names
source .env
source integrations/homeassistant/control_device.sh

echo "Testing different entity names..."

echo "1. Testing switchkv_imac:"
control_device "switchkv_imac" "turn_on" 5

echo ""
echo "2. Testing switch.kv_imac:"
control_device "switch.kv_imac" "turn_on" 5

echo ""
echo "3. Testing switch.switchkv_imac:"
control_device "switch.switchkv_imac" "turn_on" 5