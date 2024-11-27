FROM debian:bullseye-slim

# Install dependencies
RUN apt-get update && apt-get install -y curl git jq bash

# Install Ollama CLI
RUN curl -fsSL https://ollama.ai/install.sh | bash
RUN ollama pull qwen2.5-coder

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
