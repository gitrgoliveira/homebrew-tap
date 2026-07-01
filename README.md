# gitrgoliveira/homebrew-tap

A [Homebrew](https://brew.sh) tap for CLI tools by [@gitrgoliveira](https://github.com/gitrgoliveira).

## Usage

```bash
brew tap gitrgoliveira/tap
brew trust gitrgoliveira/tap   # newer Homebrew only: trust the third-party tap
brew install bracket-creator
```

(Newer Homebrew refuses to load formulae from an untrusted third-party tap until you run `brew trust gitrgoliveira/tap`; older versions have no such command and can skip that line.)

To update:

```bash
brew upgrade bracket-creator
```

## Formulae

| Formula | Description |
|---|---|
| [`bracket-creator`](Formula/bracket-creator.rb) | Generate kendo tournament brackets as Excel spreadsheets (CLI + web app). Source: [gitrgoliveira/bracket-creator](https://github.com/gitrgoliveira/bracket-creator). |

`bracket-creator` builds from source, so it needs a C toolchain (the Xcode Command Line Tools on macOS or `build-essential` on Linux) and network access for Go module downloads.
