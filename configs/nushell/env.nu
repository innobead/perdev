# env.nu — appended to Home Manager's generated env.nu via programs.nushell.extraEnv
# Loaded before config.nu on every shell start (interactive and non-interactive).

# ── PATH ─────────────────────────────────────────────────────────────────────
$env.PATH = ($env.PATH | split row (char esep) | prepend [
    ($env.HOME | path join ".cargo" "bin")
    ($env.HOME | path join ".local" "bin")
    ($env.HOME | path join ".nix-profile" "bin")
    "/nix/var/nix/profiles/default/bin"
] | uniq)

# ── Core env vars ─────────────────────────────────────────────────────────────
$env.EDITOR  = "nvim"
$env.VISUAL  = "nvim"
$env.PAGER   = "bat --plain"

$env.CARGO_HOME  = ($env.HOME | path join ".cargo")
$env.RUSTUP_HOME = ($env.HOME | path join ".rustup")

# ── fnm: initialize Node.js version manager ───────────────────────────────────
# Parses `fnm env --shell bash` POSIX exports and loads them into nushell.
if (which fnm | is-not-empty) {
    ^fnm env --shell bash
        | lines
        | where { |l| ($l | str starts-with "export ") }
        | each { |l|
            let kv = ($l | str replace "export " "" | split row "=" --max 2)
            { name: $kv.0, val: ($kv | skip 1 | str join "=" | str trim --char '"') }
        }
        | each { |e| load-env { ($e.name): $e.val } }
}
