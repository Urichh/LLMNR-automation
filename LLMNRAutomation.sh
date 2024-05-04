#!/bin/bash

# First read configuration file
# Path to the configuration files
LLMNRAutomation_conf="LLMNRAutomation.conf"
Responder_conf="/usr/share/responder/Responder.conf"

# Read the LLMNRAutomation.conf file
while IFS='=' read -r setting value; do
    setting=$(echo "$setting" | tr -d '[:space:]')
    value=$(echo "$value" | tr -d '[:space:]')

    # Check if the setting exists in Responder.conf and update its value
    if grep -q "^[[:space:]]*$setting[[:space:]]*=" "$Responder_conf"; then
        sed -i "/^[[:space:]]*$setting[[:space:]]*=/ s/=.*/= $value/" "$Responder_conf"
    fi
done < "$LLMNRAutomation_conf"


