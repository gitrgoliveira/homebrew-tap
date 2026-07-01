# typed: false
# frozen_string_literal: true

# Homebrew formula for the bracket-creator CLI + mobile-app server.
#
# This is a build-from-source formula (no pre-built bottle). It reproduces the
# same asset pipeline that `make go/build` runs, but does so in a way that is
# safe inside Homebrew's build sandbox:
#
#   * The Preact runtime (normally curl'd from unpkg by the `vendor-frontend`
#     Make target, and gitignored) is declared as `resource` blocks. Homebrew
#     downloads resources BEFORE entering the sandbox, so no network is needed
#     in the install phase to fetch them.
#   * The JSX bundle (normally produced by `npx esbuild`) is built with the
#     native `esbuild` formula, avoiding Node/npm entirely.
#   * Version/commit/build-date (normally derived from `git` by
#     get_build_info.sh) are written directly, since a release tarball has no
#     .git directory.
#
# The Anton/Archivo webfonts are committed to git and ship inside the release
# tarball (as of v0.17.0), so they need no special handling here.
#
# Go module downloads still happen over the network during `go build`, which
# is permitted under a normal `brew install`. (A homebrew-core submission with
# a stricter no-network sandbox would additionally require a vendored module
# tree; that is out of scope for a personal tap.)
#
# Per-release maintenance: update `url`/`sha256` at the top to the new tag. The
# Preact resource pins change only when the web-mobile/vendor URLs change in the
# Makefile.
class BracketCreator < Formula
  desc "Generate kendo tournament brackets as Excel spreadsheets (CLI + web app)"
  homepage "https://github.com/gitrgoliveira/bracket-creator"
  url "https://github.com/gitrgoliveira/bracket-creator/archive/refs/tags/v0.17.0.tar.gz"
  sha256 "cebe971cf2b6a2289a77de2aa89bd7c22da559c9342a41781854a6ce0a827ce5"
  license "MPL-2.0"
  head "https://github.com/gitrgoliveira/bracket-creator.git", branch: "main"

  depends_on "esbuild" => :build
  depends_on "go" => :build

  # Preact runtime, mirrored from the `vendor-frontend` Make target. These are
  # embedded into the binary via //go:embed and served at runtime.
  resource "preact" do
    url "https://unpkg.com/preact@10.13.1/dist/preact.min.js"
    sha256 "bcc2b74afdd3635bd840ea2f2e8f7eabbf80d365f491474b1a60f8f226c97b1b"
  end

  resource "preact-hooks" do
    url "https://unpkg.com/preact@10.13.1/hooks/dist/hooks.umd.js"
    sha256 "e839b8e6becb972d516f0d22fc40724a2152871b621208345bac26ae81a056e4"
  end

  resource "preact-compat" do
    url "https://unpkg.com/preact@10.13.1/compat/dist/compat.umd.js"
    sha256 "27e1504e28a5d08f5e0384e9208f1bf0696e3dfb88c61848bdfc91158cda5716"
  end

  resource "preact-router" do
    url "https://unpkg.com/preact-router@4.1.2/dist/preact-router.umd.js"
    sha256 "4807939f589eb35ce3e8d907361789ac835dc3f809bef3cda06df13b762a4d0a"
  end

  def install
    # 1. Stage the Preact runtime into web-mobile/vendor/ (embedded by go:embed).
    #    The committed webfonts under vendor/fonts/ are already in the tarball.
    vendor = buildpath/"web-mobile/vendor"
    vendor.mkpath
    resource("preact").stage       { vendor.install "preact.min.js" }
    resource("preact-hooks").stage { vendor.install "hooks.umd.js" }
    resource("preact-compat").stage { vendor.install "compat.umd.js" }
    resource("preact-router").stage { vendor.install "preact-router.umd.js" }

    # 2. Compile the JSX bundle with the native esbuild binary (mirrors the
    #    esbuild-jsx Make target: same loader/factory/fragment flags).
    dist = buildpath/"web-mobile/dist"
    dist.mkpath
    # esbuild is a build dependency, so its binary is on PATH during install.
    system "esbuild", *Dir["web-mobile/js/*.jsx"],
           "--outdir=web-mobile/dist",
           "--loader:.jsx=jsx",
           "--jsx-factory=React.createElement",
           "--jsx-fragment=React.Fragment"

    # esbuild only transforms *.jsx. Hand-authored/generated plain-.js modules
    # (e.g. glossary_data.js) are imported at runtime by the compiled bundles
    # via sibling paths that resolve to /dist/, so they must sit in dist/ too.
    Dir["web-mobile/js/*.js"].each { |js| cp js, dist }

    # 3. Stamp version info directly (get_build_info.sh needs git, absent here).
    #    Mirror its own fallback convention: "unknown" when there is no real
    #    commit to report, rather than a synthetic string that looks like one.
    vdir = buildpath/"internal/cmd/version"
    # `git describe --tags` (used by make go/build) embeds the "v" prefix, so
    # match it rather than Homebrew's stripped version (0.16.3 -> v0.16.3).
    (vdir/"version.txt").write "v#{version}"
    (vdir/"commit.txt").write ENV.fetch("GIT_COMMIT", "unknown")
    # Honor SOURCE_DATE_EPOCH (respected by Homebrew's reproducible-build
    # tooling) so rebuilds of the same version/revision are byte-identical;
    # fall back to wall-clock time otherwise.
    build_time = ENV.key?("SOURCE_DATE_EPOCH") ? Time.at(ENV["SOURCE_DATE_EPOCH"].to_i).utc : Time.now.utc
    (vdir/"build_date.txt").write build_time.strftime("%Y-%m-%d %H:%M:%S %z")

    # 4. Build. CGO off + trimpath match the release build; -buildvcs=false
    #    because there is no .git in the tarball (Go 1.26 default would probe it).
    ENV["CGO_ENABLED"] = "0"
    system "go", "build", *std_go_args(ldflags: "-s -w"), "-buildvcs=false", "."

    generate_completions_from_executable(bin/"bracket-creator", "completion")
  end

  def caveats
    <<~EOS
      bracket-creator ships several subcommands:
        bracket-creator create-pools ...   # CSV -> pooled bracket Excel
        bracket-creator create-playoffs ... # CSV -> knockout bracket Excel
        bracket-creator serve               # web UI on http://localhost:8080
        bracket-creator mobile-app          # live-tournament app on :8080

      Run `bracket-creator --help` for the full command list.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bracket-creator version")
    system bin/"bracket-creator", "--help"

    # Regression guard for this formula's whole reason to exist: the embedded
    # web assets (Preact runtime, compiled JSX bundle, generated glossary data,
    # webfonts) must actually be present in the binary. Each was missing at some
    # point during development and none of that is visible to a --help check, so
    # boot the server and assert every asset tree resolves.
    port = free_port
    data = testpath/"tournament-data"
    data.mkpath
    pid = fork do
      exec({ "PORT" => port.to_s, "TOURNAMENT_DATA_DIR" => data.to_s },
           bin/"bracket-creator", "mobile-app")
    end
    begin
      %w[
        /dist/app.js
        /dist/glossary_data.js
        /vendor/preact.min.js
        /vendor/fonts/anton/anton-latin.woff2
      ].each do |path|
        system "curl", "--fail", "--silent", "--show-error",
               "--retry-connrefused", "--retry", "20", "--retry-delay", "1",
               "http://127.0.0.1:#{port}#{path}"
      end
    ensure
      # Tolerate the server having already exited: ESRCH (no such process) and
      # ECHILD (already reaped) here would otherwise mask a real curl failure.
      begin
        Process.kill("TERM", pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
  end
end
