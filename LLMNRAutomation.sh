#!/bin/bash

# Update user preferences
# Path to the configuration files
LLMNRAutomation_conf="LLMNRAutomation.conf"
Responder_conf="/usr/share/responder/Responder.conf"

# Read the LLMNRAutomation.conf file
while IFS='=' read -r setting value; do
    setting=$(echo "$setting" | tr -d '[:space:]')
    value=$(echo "$value" | tr -d '[:space:]')

    if grep -q "^$setting" "$Responder_conf"; then
        sed -i "s/^$setting.*$/& = $value/" "$Responder_conf"
    fi
done < "$LLMNRAutomation_conf"

