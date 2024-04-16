# Base image for your application
FROM ubuntu:20.04

# Update package lists
RUN apt-get update

# Install dependencies (consider using specific versions if needed)
RUN apt-get install -y curl gnupg jq

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make the downloaded binary executable
RUN chmod +x kubectl

# Move the binary to a standard location (optional)
RUN mv kubectl /usr/local/bin/kubectl

COPY VaultInit.sh /

RUN chmod +x /VaultInit.sh

ENV NAMESPACE=

ENV VAULT_NAME=

CMD ["/bin/bash", "/VaultInit.sh"]
