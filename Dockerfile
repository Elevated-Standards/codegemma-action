FROM ubuntu:20.04

# Install dependencies
RUN apt-get update && apt-get install -y \
  curl git jq

# Install Ollama CLI
RUN curl -fsSL https://ollama.ai/install.sh | bash

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Set permissions and entrypoint
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
