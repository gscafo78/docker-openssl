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

# Function to check if a given name is empty and generate a composed CN if it is
is_empty_name() {
    local checkempty="$1"
    local prefix="$2"
    if [ -z "$checkempty" ]; then
        checkempty="${prefix}$(generate_composed_cn)"
    fi
    echo "$checkempty"
}

# Function to generate a certificate
generate_certificate() {
    local cert_type=$1 # ca/server/client/dh
    local cert_folder=$2
    local cert_config=$3
    local certname=$4
    local RANDOM_CN

    # Create the certificate folder if it does not exist
    mkdir -p "${cert_folder}"

    case $cert_type in
        ca)
            # Setup the CA folder if it does not already exist
            if [ -z "$(ls -A "${cert_folder}")" ]; then
                echo "Setting up CA folder..."
                mkdir -p "${cert_folder}/private" "${cert_folder}/newcerts"
                touch "${cert_folder}/index.txt"
                echo 1000 > "${cert_folder}/serial"
                dd if=/dev/urandom of="${cert_folder}/private/.rand" bs=256 count=1
            fi

            export RANDOM_CN=$(is_empty_name "${certname}" "CA_")
            openssl genrsa -out "${cert_folder}/private/CA.key" 4096
            openssl req -x509 -new -nodes -key "${cert_folder}/private/CA.key" -sha256 -days 3650 -out "${cert_folder}/CA.pem" -subj "/CN=${RANDOM_CN}" -config "${cert_config}/openssl.cfg"
            chmod 600 "${cert_folder}/private/CA.key"
            return 0
        ;;
        server)
            if [ -f /opt/certs/ca/private/CA.key ]; then
                export RANDOM_CN=$(is_empty_name "${certname}" "Server_")
                echo "Generated Server CN: ${RANDOM_CN}"
            else
                echo "No Certification Authority found, please generate it first"
                return 1
            fi
        ;;
        client)
            if [ -f /opt/certs/ca/private/CA.key ]; then
                export RANDOM_CN=$(is_empty_name "${certname}" "")
                echo "Generated Client CN: ${RANDOM_CN}"
            else
                echo "No Certification Authority found, please generate it first"
                return 1
            fi
        ;;
        dh)
            echo "Generating DH parameters..."
            openssl dhparam -out "${cert_folder}/dh.pem" "${DH_KEY_SIZE}"
            return 0
        ;;
        *)
            echo "Invalid certificate type specified"
            return 1
        ;;
    esac

    # Generate the certificate signing request (CSR) and key
    echo "Generating certificate for ${cert_type} with CN=${RANDOM_CN}..."
    openssl req -new -newkey rsa:4096 -nodes -out "${cert_folder}/${cert_type}.csr" -keyout "${cert_folder}/${cert_type}.key" -subj "/CN=${RANDOM_CN}" -config "${cert_config}/openssl.cfg"
    # Sign the CSR with the CA to produce the certificate
    openssl ca -batch -config "${cert_config}/ca.cfg" -in "${cert_folder}/${cert_type}.csr" -out "${cert_folder}/${cert_type}.crt"
    # Remove the CSR file and set appropriate permissions on the key
    rm -f "${cert_folder}/${cert_type}.csr"
    chmod 600 "${cert_folder}/${cert_type}.key"
}

# ========= Main ===========

# Define directories for CA and certificates
cafolder=/opt/certs/ca
certsclient=/opt/certs/client
certsserver=/opt/certs/server
certconfig=/opt/certs/config

# Move configuration files if they exist in /tmp
mkdir -p ${certconfig}
if [ -f "/tmp/openssl.cfg" ] && [ -f "/tmp/ca.cfg" ]; then
    mv /tmp/*.cfg "${certconfig}"
else
    echo "Missing configuration files in /tmp"
    exit 1
fi

# Generate CA certificate if requested
if [ "${GENERATE_CA_CERT}" = "true" ]; then
    generate_certificate "ca" "${cafolder}" "${certconfig}" "${CA_NAME}"
fi

# Generate DH parameters if requested and valid
if is_valid_dh_key_size "$DH_KEY_SIZE" && [ "${GENERATE_DH_CERT}" = "true" ]; then
    echo "Valid DH key size!"
    generate_certificate "dh" "${certsserver}" "${certconfig}"
elif [ "${GENERATE_DH_CERT}" = "true" ]; then
    echo "Invalid DH key size. Please enter a power of 2 between 256 and 4096."
    exit 1
fi

# Generate server certificate if requested
if [ "${GENERATE_SERVER_CERT}" = "true" ]; then
    generate_certificate "server" "${certsserver}" "${certconfig}" "${SERVER_NAME}"
fi

# Generate client certificate if requested
if [ "${GENERATE_CLIENT_CERT}" = "true" ]; then
    generate_certificate "client" "${certsclient}" "${certconfig}" "${CLIENT_NAME}"
fi

# Start the application passed as arguments to the script
exec "$@"
