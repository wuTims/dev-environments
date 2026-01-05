# Extension Security Audit

Last updated: 2025-01-05

## Overview

All extensions in this repository have been vetted for:
1. **Verified Publisher** - Blue checkmark indicating domain verification + 6 months good standing
2. **Download Count** - High adoption indicates community trust
3. **Source Availability** - Preference for open-source extensions
4. **Minimal Permissions** - Only essential capabilities

## Risk Context

Per [Microsoft's security blog](https://developer.microsoft.com/blog/security-and-trust-in-visual-studio-marketplace) and [2025 security research](https://www.ox.security/blog/can-you-trust-that-verified-symbol-exploiting-ide-extensions-is-easier-than-it-should-be/), even "verified" extensions can pose risks. Our mitigation strategy:

1. Use only well-established extensions from major publishers (Microsoft, Red Hat, etc.)
2. Prefer extensions with millions of installs
3. Avoid lesser-known extensions even if tempting features
4. Run containers with limited host access

## Approved Extensions

### Base Extensions (all images)

| Extension | Publisher | Verified | Downloads | Notes |
|-----------|-----------|----------|-----------|-------|
| ms-python.python | Microsoft | Yes | 100M+ | Core Python support |
| eamodio.gitlens | GitKraken | Yes | 30M+ | Git visualization |
| mhutchie.git-graph | mhutchie | Yes | 7M+ | Git graph viewer |
| ms-azuretools.vscode-docker | Microsoft | Yes | 20M+ | Docker integration |
| streetsidesoftware.code-spell-checker | Street Side Software | Yes | 10M+ | Spell checking |
| usernamehw.errorlens | Alexander | Yes | 8M+ | Inline error display |
| oderwat.indent-rainbow | oderwat | Yes | 10M+ | Indent visualization |
| gruntfuggly.todo-tree | Gruntfuggly | Yes | 7M+ | TODO tracking |
| tamasfe.even-better-toml | tamasfe | Yes | 4M+ | TOML support |
| redhat.vscode-yaml | Red Hat | Yes | 15M+ | YAML support |
| esbenp.prettier-vscode | Prettier | Yes | 40M+ | Code formatter |
| ms-vscode-remote.remote-containers | Microsoft | Yes | 20M+ | Dev containers |
| ms-vscode-remote.remote-ssh | Microsoft | Yes | 15M+ | SSH remote |

### Python Extensions

| Extension | Publisher | Verified | Downloads | Notes |
|-----------|-----------|----------|-----------|-------|
| ms-python.vscode-pylance | Microsoft | Yes | 70M+ | Type checking |
| charliermarsh.ruff | Astral Software | Yes | 5M+ | Fast linter |
| ms-python.mypy-type-checker | Microsoft | Yes | 2M+ | MyPy integration |
| littlefoxteam.vscode-python-test-adapter | Little Fox Team | Yes | 500K+ | Test adapter |

### Node Extensions

| Extension | Publisher | Verified | Downloads | Notes |
|-----------|-----------|----------|-----------|-------|
| ms-vscode.vscode-typescript-next | Microsoft | Yes | 3M+ | Latest TS |
| biomejs.biome | Biome | Yes | 300K+ | Linter/formatter |
| dbaeumer.vscode-eslint | Dirk Baeumer | Yes | 30M+ | ESLint support |
| dsznajder.es7-react-js-snippets | dsznajder | Yes | 10M+ | React snippets |
| styled-components.vscode-styled-components | Styled Components | Yes | 3M+ | CSS-in-JS |
| bradlc.vscode-tailwindcss | Tailwind Labs | Yes | 10M+ | Tailwind support |
| vitest.explorer | Vitest | Yes | 500K+ | Vitest integration |
| ms-playwright.playwright | Microsoft | Yes | 1M+ | E2E testing |
| formulahendry.auto-rename-tag | Jun Han | Yes | 15M+ | Tag renaming |
| christian-kohler.path-intellisense | Christian Kohler | Yes | 10M+ | Path completion |

## Removed/Rejected Extensions

Extensions considered but rejected for security or bloat reasons:

| Extension | Reason |
|-----------|--------|
| Various AI chat extensions | Unknown publishers, excessive permissions |
| Deprecated linters | Superseded by Ruff/Biome |
| Theme packs | Unnecessary bloat |
| Snippet packs from unknown publishers | Security risk not worth convenience |

## Adding New Extensions

Before adding a new extension:

1. Check verified publisher status on marketplace
2. Verify download count (prefer >100K installs)
3. Check for recent updates (abandoned = risk)
4. Review permissions requested
5. Search for any security advisories
6. Add to this audit document

## References

- [VS Code Extension Security](https://code.visualstudio.com/docs/configure/extensions/extension-runtime-security)
- [Microsoft Marketplace Security](https://developer.microsoft.com/blog/security-and-trust-in-visual-studio-marketplace)
- [Wiz Supply Chain Research](https://www.wiz.io/blog/supply-chain-risk-in-vscode-extension-marketplaces)
