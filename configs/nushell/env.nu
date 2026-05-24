# env.nu — appended to Home Manager's generated env.nu via programs.nushell.extraEnv
# Loaded before config.nu on every shell start (interactive and non-interactive).
#
# NOTE: home.sessionPath in home.nix only applies to POSIX shells (bash/zsh via
# ~/.profile). When Ghostty launches nu directly (no bash intermediary), the Nix
# profile paths are absent. Prepend them here so atuin/zoxide hooks can find
# their binaries before config.nu runs.

# ── PATH: Nix profiles + user tool directories ────────────────────────────────
$env.PATH = ($env.PATH | split row (char esep) | prepend [
    "/nix/var/nix/profiles/default/bin"
    ($env.HOME | path join ".nix-profile" "bin")
    ($env.HOME | path join ".cargo" "bin")
    ($env.HOME | path join ".local" "bin")
    ($env.HOME | path join ".bun" "bin")
] | uniq)

# ── Core env vars ─────────────────────────────────────────────────────────────
$env.EDITOR  = "nvim"
$env.VISUAL  = "nvim"
$env.PAGER   = "bat --plain"

$env.CARGO_HOME  = ($env.HOME | path join ".cargo")
$env.RUSTUP_HOME = ($env.HOME | path join ".rustup")
$env.BUN_INSTALL  = ($env.HOME | path join ".bun")
