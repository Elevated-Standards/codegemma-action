FROM ubuntu:20.04

# Install dependencies
RUN apt-get update && apt-get install -y curl jq git

# Install Ollama CLI
RUN curl -fsSL https://ollama.ai/install.sh | bash

# Start the Ollama service
RUN nohup ollama serve &

# Pre-pull the required model
RUN ollama pull qwen2.5-coder:7b

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
