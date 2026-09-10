# Ecosystem Coverage

Use this reference to choose the helper argument and to distinguish a direct
package review from a repository-wide scan. Socket's support matrix changes,
so verify unusual or newly added ecosystems against the [Socket ecosystem
support page](https://docs.socket.dev/docs/language-support).

## Direct package reviews

`scripts/check_dependency.sh` accepts the aliases below and converts them to
Socket PURL types before invoking the CLI.

| Accepted inputs | Socket PURL type | Package manager | Coverage note |
| --- | --- | --- | --- |
| `npm`, `javascript`, `typescript`, `yarn`, `pnpm`, `bun`, `vlt` | `npm` | npm-compatible registries | GA |
| `pypi`, `python`, `pip`, `uv`, `poetry`, `pdm` | `pypi` | PyPI-compatible registries | GA |
| `go`, `golang` | `golang` | Go Modules | GA |
| `maven`, `java`, `scala`, `kotlin`, `gradle`, `sbt` | `maven` | Maven/Gradle | GA |
| `gem`, `ruby`, `rubygems`, `bundler` | `gem` | RubyGems | GA |
| `nuget`, `dotnet` | `nuget` | NuGet | GA |
| `cargo`, `rust` | `cargo` | Cargo/crates.io | GA; Rust support is included |
| `composer`, `packagist`, `php` | `composer` | Composer/Packagist | Beta/experimental; call this out in the review |

The helper's `deep` mode invokes `socket package score`, which includes the
package's transitive dependencies. Its `shallow` mode invokes
`socket package shallow` and must not be used as evidence that the dependency
tree is safe. See the [Socket package command reference](https://docs.socket.dev/docs/socket-package).

For namespaced packages, pass the package portion expected by the PURL. For
example, use `org.example/artifact` for a Maven coordinate and the full module
path for Go. The generated PURL is printed in the helper result and should be
included in the review record.

## Repository-wide scans

Use `socket scan create <path>` locally or `socket ci` in CI when the task is
to audit the project's dependency graph rather than one proposed package.
Commit lockfiles where the ecosystem supports them so the scan can resolve the
actual versions and transitive tree.

| Ecosystem | Files to inspect | Guidance |
| --- | --- | --- |
| JavaScript/TypeScript | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, and workspace files | Include the lockfile and workspace overrides. |
| Python | `pyproject.toml`, `uv.lock`, `poetry.lock`, `Pipfile.lock`, `requirements*.txt` | Prefer a deterministic lockfile; Socket recommends `uv` when practical. |
| Go | `go.mod`, `go.sum` | Review module paths and replace directives. |
| Java/Scala/Kotlin | `pom.xml`, Gradle files, `gradle.lockfile`, `libs.versions.toml`, `build.sbt` | Gradle facts/lockfiles may be needed for complete resolution. |
| Ruby | `Gemfile`, `Gemfile.lock`, `*.gemspec` | `Gemfile.lock` gives the best accuracy. |
| .NET | `*.csproj`/other project files, `packages.lock.json`, `packages.config` | Lockfiles provide the best accuracy. |
| Rust | `Cargo.toml`, `Cargo.lock` | Cargo is fully supported; inspect `build.rs`, proc-macros, and native-code crates as build-time execution surfaces. |
| PHP | `composer.json`, `composer.lock` | Socket support is less mature; state that limitation. |
| GitHub Actions | `.github/workflows/*.yml`/`.yaml`, `action.yml`/`action.yaml` | Workflow scanning is experimental and is not a package-level `depscore` review. |
| Swift | `Package.swift`, `Package.resolved` | GA ecosystem, but current analysis is CVE-only while full support is in progress. |
| C/C++ | `conanfile.py`, `conanfile.txt` | CVE-only coverage; may require Socket Basics. |
| Julia | `Project.toml`, `Manifest.toml` | CVE-only coverage; may require Socket Basics. |
| Dart | `pubspec.yaml`, `pubspec.lock` | CVE-only coverage; may require Socket Basics. |
| Elixir/Erlang | `mix.exs`, `mix.lock` | CVE-only coverage; may require Socket Basics. |

Run `scripts/discover_scan_targets.sh <path>` before a repository-wide scan to
inventory these files and emit the coverage warning next to each detected
ecosystem. These discovery-only ecosystems are intentionally not accepted as
direct inputs to `check_dependency.sh`; do not silently map them to npm or
classify them from an unrelated package score.

Socket also offers specialized scanning for Chrome extensions, Firefox add-ons,
OpenVSX extensions, and AI model artifacts. A generic `manifest.json` is too
ambiguous for automatic discovery, so inspect those explicitly and record the
specialized scanner's maturity level.

## MCP batching

When `depscore` is available, submit all proposed packages in one request with
the correct ecosystem for each package. Compare the returned PURLs with the
requested set: a package omitted from the response is unreviewed, not safe.
