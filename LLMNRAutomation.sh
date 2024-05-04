#!/bin/bash

# Update settings from configuration file
LLMNRAutomation_conf="LLMNRAutomation.conf"
Responder_conf="/usr/share/responder/Responder.conf"

# Function to strip leading and trailing whitespace
trim() {
    echo "$1" | awk '{$1=$1};1'
}

# Read the configuration file
while IFS='=' read -r key value; do
    key=$(trim "$key")
    value=$(trim "$value")

    # Skip comments
    if [[ $key =~ ^#|^$ ]]; then
        continue
    fi

    declare "$key=$value"

    # Update Responder configuration file if key exists
    if grep -q "^[[:space:]]*$key[[:space:]]*=" "$Responder_conf"; then
        sed -i "/^[[:space:]]*$key[[:space:]]*=/ s/=.*/= $value/" "$Responder_conf"
    fi
done < "$LLMNRAutomation_conf"

# Function to check if a string is a valid IPv4 address for external IP flag
is_valid_ipv4() {
    local ipv4=$1
    if [[ "$ipv4" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Run responder
run_responder() {
    local cmd="sudo responder"
    cmd+=" -I $Interface"
    if [ "$WPAD" = "On" ]; then
        cmd+=" -wd"
    fi
    if [ "$AuthMethod" = "Basic" ]; then
        cmd+=" -b"
    fi
    if [ "$WPAD" = "On" ] && [ "$AuthMethod" = "Basic" ]; then
        cmd+="F"
    fi
    if [ "$DNS_DHCP" = "On" ]; then
        cmd+=" -D"
    fi
    if [ "$Address" != "None" ] && is_valid_ipv4 "$Address"; then
        cmd+=" -e $Address"
    fi
    if [ "$AuthMethod" != "NTLMv2-SSP" ]; then
        cmd+=" --lm --disable-ess"
    fi
    echo "Running responder with command: $cmd"

    eval "$cmd"
}

main() {
    # Extract interface from Responder config
    Interface=$(grep -oP '^Interface\s*=\s*\K.*' "$LLMNRAutomation_conf" | tr -d '[:space:]')

    run_responder
}

main