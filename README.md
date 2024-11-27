A GitHub Action that runs the [Ollama CodeGemma](https://ollama.ai) model on files changed in a pull request and creates a GitHub issue with AI-generated recommendations.

## Features

- Automatically detects files changed in a pull request.
- Runs the Ollama CodeGemma model on the changed files.
- Creates a GitHub issue summarizing recommendations for the pull request.
- Prevents duplicate issues by checking for existing recommendations.

## Usage

Add the following to your workflow file (e.g., `.github/workflows/ollama-codegemma.yml`):

```yaml
name: Code Review

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: write
  pull-requests: write

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      with:
        fetch-depth: 0

    - name: Get changed files
      id: get_diff
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} || ${{ secrets.CODEGEMMA }}
      uses: tj-actions/changed-files@v36

    - name: Run Ollama CodeGemma
      uses: Elevated-Standards/codegemma-action@main
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }} || ${{ secrets.CODEGEMMA }}
        changed_files: ${{ steps.get_diff.outputs.all_changed_and_modified_files }}
```

## Inputs

| Name          | Required | Default | Description                                |
|---------------|----------|---------|--------------------------------------------|
| `github_token`| Yes      | N/A     | GitHub token used to create issues.       |


## Output

| Name             | Description                                |
|------------------|--------------------------------------------|
| `recommendations`| The AI-generated recommendations for files.|



## How it Works

- Detects files changed in the pull request.
- Runs the Ollama CodeGemma model on the changed files.
- Generates AI-based recommendations for each file.
- Creates or updates a GitHub issue summarizing the recommendations.

## Prerequisites

- GitHub Repository: Ensure your repository allows workflow execution.
- Secrets: GITHUB_TOKEN must be available in the workflow context.















