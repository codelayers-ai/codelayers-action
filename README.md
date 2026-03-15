# CodeLayers Action

Visualize every PR as a 3D dependency graph. See blast radius, trace imports, and understand the impact of changes automatically.

**Free for open source. No account required.**

## Quick Start

Add this to `.github/workflows/codelayers.yml`:

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
```

No API key. No sign-up. Every PR gets a comment with an interactive 3D visualization link.

### Private Repos

For private repositories, add an API key:

```yaml
      - uses: codelayers-ai/codelayers-action@v1
        with:
          api_key: ${{ secrets.CODELAYERS_API_KEY }}
```

<details>
<summary>How to get an API key</summary>

```bash
brew install codelayers-ai/tap/codelayers
codelayers login
codelayers api-keys create "GitHub CI"
```

Add the key as a repository secret named `CODELAYERS_API_KEY`. Requires a [CodeLayers Pro](https://codelayers.ai) subscription.

</details>

## What Reviewers See

Every PR comment includes a link to an interactive 3D visualization:

- **Blast radius**: changed files in red, affected dependencies in orange/yellow gradient by distance
- **Dependency graph**: click any file to see its imports and dependents
- **Code metrics**: LOC, complexity, and entry points per file
- **Language breakdown**: top languages in the codebase at a glance

Open source repos get a public explore link. Private repos get a zero-knowledge encrypted link (code is encrypted client-side, the server never sees it).

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api_key` | No | | API key for private repos. Not needed for public repos. |
| `base_branch` | No | auto-detect | Base branch to compare against |
| `expires_days` | No | `7` | Days until visualization link expires |
| `max_views` | No | unlimited | Maximum number of views (private repos only) |
| `comment` | No | `true` | Post/update PR comment |
| `link_to_pr` | No | `true` | Link visualization to GitHub repo/PR metadata |

## Outputs

| Output | Description |
|--------|-------------|
| `share_url` | Visualization URL |
| `share_id` | Share/explore ID (UUID) |
| `node_count` | Number of nodes in the graph |
| `file_count` | Number of files in the graph |
| `changed_file_count` | Number of files changed in the PR |
| `blast_radius_count` | Total files affected by changes (via dependency graph) |

## How It Works

1. Parses your codebase with tree-sitter (10 languages)
2. Builds a dependency graph (functions, classes, imports, calls)
3. Computes blast radius from PR changes
4. Posts a comment with the visualization link

For private repos, code is encrypted client-side with a random key. The key lives in the URL fragment and is never sent to the server.

## Using Outputs

```yaml
- uses: codelayers-ai/codelayers-action@v1
  id: codelayers

- name: Custom comment
  run: |
    echo "Share URL: ${{ steps.codelayers.outputs.share_url }}"
    echo "Changed files: ${{ steps.codelayers.outputs.changed_file_count }}"
    echo "Blast radius: ${{ steps.codelayers.outputs.blast_radius_count }}"
```

## Entire.io Support

If your repo uses [Entire.io](https://entire.io), CodeLayers automatically detects the `entire/checkpoints/v1` branch and shows AI agent attribution in the visualization, showing which files were written by Claude Code, Copilot, or Gemini CLI and which were human-authored. No extra configuration needed.

## Supported Languages

Rust, TypeScript/JavaScript, Python, Java, Go, C++, C#, Ruby, PHP, Swift

## Links

- [Website](https://codelayers.ai/)
- [App Store](https://apps.apple.com/app/codelayers/id6756067177)
- [CLI Installation](https://github.com/codelayers-ai/homebrew-tap)
