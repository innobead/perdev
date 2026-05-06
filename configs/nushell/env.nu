# env.nu — appended to Home Manager's generated env.nu via programs.nushell.extraEnv
# Loaded before config.nu on every shell start (interactive and non-interactive).

# ── PATH ─────────────────────────────────────────────────────────────────────
$env.PATH = ($env.PATH | split row (char esep) | prepend [
    ($env.HOME | path join ".cargo" "bin")
    ($env.HOME | path join ".local" "bin")
    ($env.HOME | path join ".bun" "bin")
    ($env.HOME | path join ".nix-profile" "bin")
    "/nix/var/nix/profiles/default/bin"
] | uniq)

# ── Core env vars ─────────────────────────────────────────────────────────────
$env.EDITOR  = "nvim"
$env.VISUAL  = "nvim"
$env.PAGER   = "bat --plain"

$env.CARGO_HOME  = ($env.HOME | path join ".cargo")
$env.RUSTUP_HOME = ($env.HOME | path join ".rustup")
$env.BUN_INSTALL  = ($env.HOME | path join ".bun")
