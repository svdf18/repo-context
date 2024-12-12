# Repo Context Tool

A command-line tool to analyze and create context files for GitHub repositories.

## Dependencies

- brew install fd
- brew install tree

## Make script executable

`chmod +x repo-context.sh`

## Run directly from current directory

`./repo-context.sh <URL>`

## Installation

1. Clone this repository
2. Copy repo-context.sh to ~/bin/repo-context
3. Make it executable: chmod +x ~/bin/repo-context
4. Add to PATH: export PATH="$HOME/bin:$PATH"

## Usage

```bash
repo-context https://github.com/username/repository
```
