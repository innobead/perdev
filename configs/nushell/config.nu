# config.nu — appended to Home Manager's generated config.nu via programs.nushell.extraConfig
# Runs after Home Manager integration snippets (starship, carapace, zoxide, atuin).
# Modifies specific $env.config fields rather than replacing the whole record.

# ── Core settings ─────────────────────────────────────────────────────────────
$env.config.show_banner     = false
$env.config.edit_mode       = "vi"
$env.config.table.mode      = "rounded"
$env.config.table.index_mode = "always"
$env.config.completions.algorithm = "fuzzy"

# sqlite history required for atuin
$env.config.history.file_format  = "sqlite"
$env.config.history.max_size     = 100_000
$env.config.history.sync_on_enter = true

# ── direnv hook ───────────────────────────────────────────────────────────────
# direnv has no built-in nushell hook generator; this minimal hook fires on
# every prompt render and loads env changes when .envrc is present.
if (which direnv | is-not-empty) {
    $env.config.hooks.pre_prompt = (
        $env.config.hooks.pre_prompt | append [{||
            if (".envrc" | path exists) or ("DIRENV_FILE" in $env) {
                direnv export json | from json | load-env
            }
        }]
    )
}

# ── Aliases ───────────────────────────────────────────────────────────────────
alias ls   = eza --icons --group-directories-first
alias ll   = eza --icons --group-directories-first -la
alias lt   = eza --icons --group-directories-first --tree -L 2
alias cat  = bat
alias grep = rg

# Kubernetes
alias k    = kubectl
alias kctx = kubectx
alias kns  = kubens
alias h    = helm

# TUI helpers
alias lg   = lazygit
alias ld   = lazydocker
