# Security policy

## Supported versions

clipsweep is a local-only macOS tool with no network surface. Only the latest tagged release is supported. Prior versions receive no patches.

| version | supported |
|---------|-----------|
| 0.2.x   | yes       |
| < 0.2   | no        |

## Threat model

clipsweep reads and writes the macOS pasteboard via `hs.pasteboard`. Clipboard contents routinely include secrets: passwords, API keys, OAuth tokens, signed URLs, private keys. The following are in scope:

- A bug that leaks clipboard contents to a log, to disk, to a third-party process, or to any non-clipboard sink.
- A bug that mutates the clipboard in an unintended way (e.g., corrupting a token mid-paste).
- A bug that allows arbitrary code execution via the public `M.clean(text, opts)` API on user-supplied input.

Out of scope:

- Hammerspoon-the-runtime issues. Report at https://github.com/Hammerspoon/hammerspoon.
- macOS clipboard policy and pasteboard isolation between apps. Report to Apple.
- Misuse of the public `M.clean` API by a malicious local caller. clipsweep runs in the user's own Lua process; the caller is the user.

## Reporting a vulnerability

Open a private security advisory at https://github.com/rgsuarez/clipsweep/security/advisories/new. Do not file a public issue, pull request, or Discussions thread until a fix is released and the advisory is published.

Include:

- A minimal reproducible clipboard input (paste between fenced blocks; use `printf` or hex for exact bytes when line endings or BOM matter).
- The expected vs. observed behavior.
- The version: a commit SHA or release tag.
- macOS and Hammerspoon versions.

You may also email richie@liquid.ai if you cannot use GitHub.

## Disclosure timeline

- Within 5 business days: acknowledgment.
- Within 30 days: an assessment and a target fix timeline.
- After a fix lands and a release is tagged: the advisory is published with credit to the reporter (or anonymous, your choice).

This is a small single-author project. Expect best-effort, not enterprise SLA.
