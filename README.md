# CodeLayers Action

Generate a 3D code visualization for every PR automatically. Posts a comment with an interactive share link showing your codebase as a spatial graph with blast radius highlighting.

## Quick Start

```yaml
name: CodeLayers
on:
  pull_request:

jobs:
  visualize:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: codelayers-ai/codelayers-action@v1
        with:
          api_key: ${{ secrets.CODELAYERS_API_KEY }}
```

## Pricing

Shared visualization links are **free** — anyone with the link can view the 3D graph in their browser.

To generate an API key, you need the [CodeLayers app](https://apps.apple.com/app/codelayers/id6756067177) (subscription required).

## Setup

1. Install the CLI and create an API key:
   ```bash
   brew install codelayers-ai/tap/codelayers
   codelayers login
   codelayers api-keys create "GitHub CI"
   ```

2. Add the key as a repository secret named `CODELAYERS_API_KEY`

3. Add the workflow above to `.github/workflows/codelayers.yml`

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api_key` | Yes | | CodeLayers API key |
| `base_branch` | No | auto-detect | Base branch to compare against |
| `expires_days` | No | `7` | Days until share link expires |
| `max_views` | No | unlimited | Maximum number of views |
| `comment` | No | `true` | Post/update PR comment |
| `link_to_pr` | No | `true` | Link share to GitHub repo/PR metadata |
| `cli_image` | No | `ghcr.io/codelayers-ai/codelayers-cli:latest` | CLI Docker image |

## Outputs

| Output | Description |
|--------|-------------|
| `share_url` | Full share URL with encryption key |
| `share_id` | Share ID (UUID) |
| `node_count` | Number of nodes in the graph |
| `file_count` | Number of files in the graph |
| `changed_file_count` | Number of files changed in the PR |
| `blast_radius_count` | Total files affected by changes (via dependency graph) |

## How It Works

1. Parses your codebase with tree-sitter (10 languages supported)
2. Builds a dependency graph (functions, classes, imports, calls)
3. Computes blast radius from PR changes
4. Encrypts with a random key (zero-knowledge — server never sees your code)
5. Uploads encrypted blob and posts a comment with the share link
6. The encryption key is in the URL fragment (never sent to the server)

### What reviewers see

- **Blast radius** — changed files highlighted in red, with affected dependencies shown in an orange/yellow gradient by distance
- **Dependency graph** — click any file to see its imports and dependents
- **Code metrics** — LOC, complexity, and entry points per file
- **Language breakdown** — top languages in the codebase at a glance

## Using Outputs

```yaml
- uses: codelayers-ai/codelayers-action@v1
  id: codelayers
  with:
    api_key: ${{ secrets.CODELAYERS_API_KEY }}
    comment: false  # we'll post our own comment

- name: Custom comment
  run: |
    echo "Share URL: ${{ steps.codelayers.outputs.share_url }}"
    echo "Changed files: ${{ steps.codelayers.outputs.changed_file_count }}"
    echo "Blast radius: ${{ steps.codelayers.outputs.blast_radius_count }}"
```

## Supported Languages

Rust, TypeScript/JavaScript, Python, Java, Go, C++, C#, Ruby, PHP, Swift

## Links

- [Website](https://codelayers.ai/)
- [App Store](https://apps.apple.com/app/codelayers/id6756067177)
- [CLI Installation](https://github.com/codelayers-ai/homebrew-tap)
