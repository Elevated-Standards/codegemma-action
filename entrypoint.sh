#!/bin/bash

set -e

# Debugging information
echo "Current working directory: $(pwd)"
echo "Contents of workspace:"
ls -al

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

# Ensure the working directory is a Git repository
if [ ! -d ".git" ]; then
  echo "Repository is not a valid Git repository. Initializing..."
  git init
  git remote add origin "https://github.com/${GITHUB_REPOSITORY}.git"
  git fetch --depth=1 origin "${GITHUB_REF}"
  git checkout "${GITHUB_SHA}"
  echo "Git repository initialized successfully."
else
  echo "Git repository already exists."
fi

# Analyze files with Ollama CodeGemma
RESULTS=""
while IFS= read -r FILE; do
  echo "Analyzing $FILE..."
  if [ -f "$FILE" ]; then
    OUTPUT=$(ollama codegemma --file "$FILE" || echo "Error processing $FILE")
    RESULTS="$RESULTS\n### Recommendations for $FILE\n$OUTPUT\n"
  else
    echo "File $FILE does not exist. Skipping."
  fi
done <<< "$CHANGED_FILES"

# Exit if no results
if [ -z "$RESULTS" ]; then
  echo "No recommendations generated."
  exit 0
fi

# Create a GitHub issue with recommendations
PR_NUMBER=$(jq -r '.pull_request.number' < "${GITHUB_EVENT_PATH}")
PR_URL=$(jq -r '.pull_request.html_url' < "${GITHUB_EVENT_PATH}")
ISSUE_TITLE="Ollama CodeGemma Recommendations for PR #${PR_NUMBER}"
ISSUE_BODY="## Recommendations\n\n${RESULTS}\n\n### Pull Request Link\n[View Pull Request](${PR_URL})"

EXISTING_ISSUE=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues" | \
  jq -r ".[] | select(.title == \"$ISSUE_TITLE\") | .number")

if [ -z "$EXISTING_ISSUE" ]; then
  curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -d "$(jq -n --arg title "$ISSUE_TITLE" --arg body "$ISSUE_BODY" '{title: $title, body: $body, labels: ["ollama-codegemma"]}')" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues"
  echo "Created new issue: $ISSUE_TITLE"
else
  echo "Issue already exists: $EXISTING_ISSUE"
fi
