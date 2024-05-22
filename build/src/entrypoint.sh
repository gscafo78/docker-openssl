#!/bin/bash

# Exit immediately if any command exits with a non-zero status
set -e

# Function to check if a number is a valid DH key size (256 to 4096, power of 2)
is_valid_dh_key_size() {
    local dh_key_size=$1
    if [[ $dh_key_size =~ ^[0-9]+$ && $dh_key_size -ge 256 && $dh_key_size -le 4096 ]]; then
        # Check if the number is a power of 2
        if (( (dh_key_size & (dh_key_size - 1)) == 0 )); then
            return 0  # True
        else
            return 1  # False
        fi
    else
        return 1  # False
    fi
}


# Function to generate a random Common Name (CN) by combining three random words
generate_composed_cn() {
    local random_word1=$(shuf -n 1 /usr/share/dict/words)
    local random_word2=$(shuf -n 1 /usr/share/dict/words)
    local random_word3=$(shuf -n 1 /usr/share/dict/words)
    local composed_cn="${random_word1}${random_word2}${random_word3}"
    echo "$composed_cn"
}

# Function to generate a certificate
generate_certificate() {
    local cert_folder=$1
    local cert_type=$2

    # Create the certificate folder if it does not exist
    mkdir -p "${cert_folder}"
    if [ "${cert_type}" == "server" ]; then
        # Generate Diffie-Hellman parameters if required
        if [ "${GENERATE_DH_CERT}" = "true" ]; then
            echo "Generating DH parameters..."
            openssl dhparam -out "${cert_folder}/dh.pem" "${DH_KEY_SIZE}"
        fi
        # Generate a random CN for the server certificate
        export RANDOM_CN="Server_$(generate_composed_cn)"
        echo "Generated Server CN: ${RANDOM_CN}"
    else
        # Generate a random CN for the client certificate
        export RANDOM_CN=$(generate_composed_cn)
        echo "Generated Client CN: ${RANDOM_CN}"
    fi

    # Generate the certificate signing request (CSR) and key
    echo "Generating certificate for ${cert_type} with CN=${RANDOM_CN}..."
    openssl req -new -newkey rsa:4096 -nodes -out "${cert_folder}/${cert_type}.csr" -keyout "${cert_folder}/${cert_type}.key" -subj "/CN=${RANDOM_CN}" -config "${cafolder}/openssl.cfg"
    # Sign the CSR with the CA to produce the certificate
    openssl ca -batch -config "${cafolder}/ca.cfg" -in "${cert_folder}/${cert_type}.csr" -out "${cert_folder}/${cert_type}.crt"
    # Remove the CSR file and set appropriate permissions on the key
    rm -f "${cert_folder}/${cert_type}.csr"
    chmod 600 "${cert_folder}/${cert_type}.key"
}

# Define directories for CA and certificates
cafolder=/opt/certs/ca
certsfolder=/opt/certs/client
certsserver=/opt/certs/server

if is_valid_dh_key_size "$DH_KEY_SIZE" && [ "${GENERATE_DH_CERT}" = "true" ]; then
    echo "Valid DH key size!"
elif [ "${GENERATE_DH_CERT}" = "true" ]; then
    echo "Invalid DH key size. Please enter a power of 2 between 256 and 4096."
    exit 0
fi

# Setup the CA folder if it does not already exist
if [ ! -d "${cafolder}" ]; then
    echo "Setting up CA folder..."
    mkdir -p "${cafolder}/private" "${cafolder}/newcerts"
    touch "${cafolder}/index.txt"
    echo 1000 > "${cafolder}/serial"
    dd if=/dev/urandom of="${cafolder}/private/.rand" bs=256 count=1

    # Move configuration files if they exist in /opt
    if [ -f "/tmp/openssl.cfg" ] && [ -f "/tmp/ca.cfg" ]; then
        mv /tmp/*.cfg "${cafolder}"
    else
        echo "Missing configuration files in /opt"
        exit 1
    fi

    # Generate the CA key and self-signed certificate
    echo "Generating CA key and certificate..."
    export RANDOM_CN="ATSC_CA"
    openssl genrsa -out "${cafolder}/private/CA.key" 4096
    openssl req -x509 -new -nodes -key "${cafolder}/private/CA.key" -sha256 -days 3650 -out "${cafolder}/CA.pem" -config "${cafolder}/openssl.cfg"
    chmod 600 "${cafolder}/private/CA.key"
else
    # Cleanup configuration files from /opt if the CA already exists
    for file in /opt/*.cfg; do
        if [ -f "$file" ]; then
            rm "$file"
            echo "Deleted $file"
        fi
    done
    echo "CA already exists"
fi

# Generate server certificate if requested
if [ "${GENERATE_SERVER_CERT}" = "true" ]; then
    generate_certificate "${certsserver}" "server"
fi

# Generate client certificate if requested
if [ "${GENERATE_CLIENT_CERT}" = "true" ]; then
    generate_certificate "${certsfolder}" "client"
fi

# Start the application passed as arguments to the script
exec "$@"
