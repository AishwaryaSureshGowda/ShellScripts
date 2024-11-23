#!/bin/bash

# Read the .env.aws file into arrays
keys=()
values=()
while IFS= read -r line || [ -n "$line" ]; do
    key=$(echo "$line" | cut -d '=' -f1)
    value=$(echo "$line" | cut -d '=' -f2-)
    keys+=("$key")
    values+=("$value")
done < ./.env.aws

# Process the .env.template file
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Trim leading and trailing whitespace from value
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # Search for the key in the keys array
    found=false
    for i in "${!keys[@]}"; do
        if [[ "${keys[i]}" == "$value" ]]; then
            found=true
            value="${values[i]}"
            break
        fi
    done

    # Output the key-value pair
    echo "$key=$value"
done < ./.env.template > ./.env
