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

# Atuin's generated Ctrl-R and Up bindings share the name "atuin". The
# generated Up binding is disabled in home.nix and restored here with a unique
# name so Nushell accepts the configuration without changing key behavior.
$env.config.keybindings = (
    $env.config.keybindings
    | append {
        name: atuin_up
        modifier: none
        keycode: up
        mode: [emacs, vi_normal, vi_insert]
        event: {
            until: [
                {send: menuup}
                {send: executehostcommand cmd: (_atuin_search_cmd '--shell-up-key-binding')}
            ]
        }
    }
)

# ── direnv hook ───────────────────────────────────────────────────────────────
# direnv has no built-in nushell hook generator; this minimal hook fires on
# every prompt render and loads env changes when .envrc is present.
# Guard: initialize pre_prompt to empty list if it doesn't exist yet.
if (which direnv | is-not-empty) {
    if not ("pre_prompt" in $env.config.hooks) or ($env.config.hooks.pre_prompt | is-empty) {
        $env.config.hooks.pre_prompt = []
    }
    $env.config.hooks.pre_prompt = (
        $env.config.hooks.pre_prompt | append [{||
            let de = (direnv export json | complete)
            if $de.exit_code == 0 and (($de.stdout | str trim | is-not-empty)) {
                $de.stdout | from json | load-env
            }
        }]
    )
}

# ── Aliases ───────────────────────────────────────────────────────────────────
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
