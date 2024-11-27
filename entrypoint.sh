#!/bin/bash

set -e

# Start the Ollama service in the background
echo "Starting the Ollama service..."
nohup ollama serve > /tmp/ollama.log 2>&1 &

# Wait for the service to be ready
echo "Waiting for the Ollama service to be ready..."
for i in {1..5}; do
  if curl -s http://localhost:11434/v1/models > /dev/null; then
    echo "Ollama service is ready."
    break
  fi
  echo "Retrying... ($i/5)"
  sleep 1
done

# Fail if the service is not ready
if ! curl -s http://localhost:11434/v1/models > /dev/null; then
  echo "Ollama service failed to start."
  exit 1
fi

# Ensure the required model is available
echo "Pulling the required model qwen2.5-coder:7b..."
ollama pull qwen2.5-coder:7b || { echo "Failed to pull model qwen2.5-coder:7b"; exit 1; }

# Get inputs
GITHUB_TOKEN=$1
CHANGED_FILES=$2

# Validate inputs
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN is not set."
  exit 1
fi

if [ -z "$CHANGED_FILES" ]; then
  echo "No changed files provided."
  exit 0
fi

# Split CHANGED_FILES into individual files
IFS=' ' read -r -a FILES <<< "$CHANGED_FILES"

# Set the chunk size (number of files to process in parallel)
CHUNK_SIZE=5

# Temporary file to store results
TMP_RESULTS="/tmp/results.txt"
rm -f "$TMP_RESULTS"
touch "$TMP_RESULTS"

# Process files in chunks
FILES_BATCH=()
for FILE in "${FILES[@]}"; do
  FILES_BATCH+=("$FILE")
  if [ "${#FILES_BATCH[@]}" -eq "$CHUNK_SIZE" ]; then
    # Process the current batch in parallel
    for BATCH_FILE in "${FILES_BATCH[@]}"; do
      {
        echo "Analyzing $BATCH_FILE..."
        if [ -f "$BATCH_FILE" ]; then
          FILE_CONTENT=$(cat "$BATCH_FILE")
          PROMPT="Review this code, provide suggestions for improvement, coding best practices, improve readability, and maintainability. Remove any code smells and anti-patterns. Provide code examples for your suggestion.\n\n$FILE_CONTENT"
          OUTPUT=$(ollama run qwen2.5-coder:7b "$PROMPT" || echo "Error processing $BATCH_FILE")
          echo -e "### Recommendations for $BATCH_FILE\n$OUTPUT\n" >> "$TMP_RESULTS"
        else
          echo "File $BATCH_FILE does not exist. Skipping."
        fi
      } &
    done
    wait
    FILES_BATCH=() # Reset the batch
  fi
done

# Process remaining files in the batch
if [ "${#FILES_BATCH[@]}" -gt 0 ]; then
  for BATCH_FILE in "${FILES_BATCH[@]}"; do
    {
      echo "Analyzing $BATCH_FILE..."
      if [ -f "$BATCH_FILE" ]; then
        FILE_CONTENT=$(cat "$BATCH_FILE")
        PROMPT="Review this code, provide suggestions for improvement, coding best practices, improve readability, and maintainability. Remove any code smells and anti-patterns. Provide code examples for your suggestion.\n\n$FILE_CONTENT"
        OUTPUT=$(ollama run qwen2.5-coder:7b "$PROMPT" || echo "Error processing $BATCH_FILE")
        echo -e "### Recommendations for $BATCH_FILE\n$OUTPUT\n" >> "$TMP_RESULTS"
      else
        echo "File $BATCH_FILE does not exist. Skipping."
      fi
    } &
  done
  wait
fi

# Combine results
RESULTS=$(cat "$TMP_RESULTS")
rm -f "$TMP_RESULTS"

# Debug results
echo "Generated recommendations:"
echo -e "$RESULTS"

# Exit if no results
if [ -z "$RESULTS" ]; then
  echo "No recommendations generated. Skipping issue/comment creation."
  exit 0
fi

# Check if running in a pull request context
PR_NUMBER=$(jq -r '.pull_request.number' < "${GITHUB_EVENT_PATH}")

if [ "$PR_NUMBER" != "null" ] && [ -n "$PR_NUMBER" ]; then
  echo "Pull request detected. Adding a comment to PR #${PR_NUMBER}."

  COMMENT_BODY="## Ollama CodeGemma Recommendations\n\n${RESULTS}"

  # Post comment to the pull request
  RESPONSE=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -d "$(jq -n --arg body "$COMMENT_BODY" '{body: $body}')" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments")

  COMMENT_URL=$(echo "$RESPONSE" | jq -r '.html_url')

  if [ "$COMMENT_URL" == "null" ]; then
    echo "Error adding comment to pull request: $RESPONSE"
    exit 1
  fi

  echo "Comment added to pull request: $COMMENT_URL"
else
  echo "No pull request detected. Creating a GitHub issue."

  # Create GitHub issue
  ISSUE_TITLE="Ollama CodeGemma Recommendations"
  ISSUE_BODY="## Recommendations\n\n${RESULTS}"

  RESPONSE=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -d "$(jq -n --arg title "$ISSUE_TITLE" --arg body "$ISSUE_BODY" '{title: $title, body: $body, labels: ["ollama-codegemma"]}')" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues")

  ISSUE_URL=$(echo "$RESPONSE" | jq -r '.html_url')

  if [ "$ISSUE_URL" == "null" ]; then
    echo "Error creating issue: $RESPONSE"
    exit 1
  fi

  echo "Created issue: $ISSUE_URL"
fi
