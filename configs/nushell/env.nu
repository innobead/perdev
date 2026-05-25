# env.nu — appended to Home Manager's generated env.nu via programs.nushell.extraEnv
# Loaded before config.nu on every shell start (interactive and non-interactive).
#
# NOTE: home.sessionPath in home.nix only applies to POSIX shells (bash/zsh via
# ~/.profile). When Ghostty launches nu directly (no bash intermediary), the Nix
# profile paths are absent. Prepend them here so atuin/zoxide hooks can find
# their binaries before config.nu runs.

# ── PATH: priority-ordered paths ──────────────────────────────────────────────
# Use filter-then-prepend (not | uniq) so inherited PATH order doesn't override:
# | uniq keeps the FIRST occurrence, which would be the inherited position.
let priority_paths = [
    "/opt/homebrew/bin"           # macOS: brew-managed packages take precedence
    "/opt/homebrew/sbin"
    "/nix/var/nix/profiles/default/bin"
    ($env.HOME | path join ".nix-profile" "bin")
    ($env.HOME | path join ".cargo" "bin")
    ($env.HOME | path join ".local" "bin")
    ($env.HOME | path join ".bun" "bin")
    ($env.HOME | path join "go" "bin")
]
$env.PATH = (
    $env.PATH | split row (char esep)
    | where {|p| $p not-in $priority_paths}
    | prepend $priority_paths
)

# ── Core env vars ─────────────────────────────────────────────────────────────
$env.EDITOR  = "nvim"
$env.VISUAL  = "nvim"
$env.PAGER   = "bat --plain"

$env.CARGO_HOME  = ($env.HOME | path join ".cargo")
$env.RUSTUP_HOME = ($env.HOME | path join ".rustup")
$env.BUN_INSTALL  = ($env.HOME | path join ".bun")
