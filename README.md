# gitrgoliveira/homebrew-tap

A [Homebrew](https://brew.sh) tap for CLI tools by [@gitrgoliveira](https://github.com/gitrgoliveira).

## Usage

```bash
brew tap gitrgoliveira/tap
brew install bracket-creator
```

If `brew install` refuses to load the formula from an untrusted tap (newer Homebrew only), run `brew trust gitrgoliveira/tap` and try again. Older Homebrew has no such command and does not need it.

To update:

```bash
brew upgrade bracket-creator
```

## Formulae

| Formula | Description |
|---|---|
| [`bracket-creator`](Formula/bracket-creator.rb) | Generate kendo tournament brackets as Excel spreadsheets (CLI + web app). Source: [gitrgoliveira/bracket-creator](https://github.com/gitrgoliveira/bracket-creator). |

`bracket-creator` builds from source, so it needs a C toolchain (the Xcode Command Line Tools on macOS or `build-essential` on Linux) and network access for Go module downloads.
