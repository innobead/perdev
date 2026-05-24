# env.nu — appended to Home Manager's generated env.nu via programs.nushell.extraEnv
# Loaded before config.nu on every shell start (interactive and non-interactive).
#
# NOTE: ~/.nix-profile/bin and /nix/var/nix/profiles/default/bin are prepended
# via home.sessionPath in home.nix, so HM includes them before integration
# snippets (atuin init, zoxide init) run. No need to repeat them here.

# ── Extra PATH entries not covered by home.sessionPath ────────────────────────
$env.PATH = ($env.PATH | split row (char esep) | prepend [
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
