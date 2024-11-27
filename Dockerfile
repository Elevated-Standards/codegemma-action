FROM alpine:3.18

# Install dependencies
RUN apk add --no-cache curl git jq bash

# Install Ollama CLI
RUN curl -fsSL https://ollama.ai/install.sh | bash

# Pre-pull the required model
RUN ollama pull codegemma

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
