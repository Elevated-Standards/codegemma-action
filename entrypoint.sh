#!/bin/bash

set -e

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

# Analyze files with Ollama CodeGemma
RESULTS=""
for FILE in "${FILES[@]}"; do
  echo "Analyzing $FILE..."
  if [ -f "$FILE" ]; then
    # Generate a specific prompt for the file
    PROMPT="Please review the file $FILE and provide detailed recommendations for improvement."

    # Run CodeGemma with the prompt
    OUTPUT=$(ollama codegemma --prompt "$PROMPT" --file "$FILE" || echo "Error processing $FILE")
    RESULTS="$RESULTS\n### Recommendations for $FILE\n$OUTPUT\n"
  else
    echo "File $FILE does not exist. Skipping."
  fi
done

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
