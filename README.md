![OpenVPN](https://cdn.icon-icons.com/icons2/2699/PNG/512/openssl_logo_icon_170881.png)

# Docker OpenSSL

OpenSSL 1.1.1w  11 Sep 2023, container to generate Certification Authority, certificates and keys. This allows you to use OpenSSL without needing to install it on your computer and regardless of your operating system (Linux or Windows).

# Requirement

Docker must be configured to run Linux Docker containers.

# Create Docker Container

```shell
# Change directory to project folder
cd OpenSSL/build

# Build Docker image
docker build -t 4ss078/docker-openssl:latest .

# Run Docker container in interactive mode
# Make sure you replace `<your_path>` with your target folder, this is where files will be created.
# To generate the Certification Authority just create the container

docker run -it --rm -v your_path:/opt 4ss078/docker-openssl
```

# Generate OpenSSL certificates
For generating the configuration file, you can use the environmerts:
* GENERATE_CA_CERT
* CA_NAME (if omitted will be automatically generated)
* GENERATE_SERVER_CERT
* SERVER_NAME (if omitted will be automatically generated)
* GENERATE_CLIENT_CERT
* CLIENT_NAME (if omitted will be automatically generated)
* GENERATE_DH_CERT 
* DH_KEY_SIZE (128-4096 2048 default)

# Generate Keys

Once connected to the container, execute the following commands depending on your needs:

```shell
# Create cert.key and cert.csr files for SSL encryption
docker run -it --rm -v your_path:/opt -e GENERATE_CA_CERT=true \
                                      -e GENERATE_SERVER_CERT=true \
                                      -e GENERATE_CLIENT_CERT=true \
                                      -e GENERATE_DH_CERT=true \
                                      -e DH_KEY_SIZE=2048 \
                                      -e CA_NAME=Your_CN_Name \
                                      -e SERVER_NAME=Your_Server_Name \
                                      -e CLIENT_NAME=Your_Client_Name \
                                      4ss078/docker-openssl
```