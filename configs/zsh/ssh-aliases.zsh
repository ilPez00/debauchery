# ssh-aliases.zsh — fleet SSH short hops for air.
#
# Deployed to ~/.config/fleet/ssh-aliases.zsh by
# debauchery/scripts/09-ssh-aliases.sh and sourced from ~/.zshrc.
#
# Hosts come from ~/.ssh/config (tailscale-first), so there are no IPs here and
# nothing drifts. ~/.fleet_aliases.sh already provides the plain host aliases
# (omo, pansa, feather, pie, k1, fts); these are the two-letter hops plus the
# cases those don't cover.

# --- short hops ------------------------------------------------------------
alias so='ssh omo'
alias sp='ssh pansa'
alias spi='ssh pi'
alias sf='ssh feather'
alias sk1='ssh k1'                       # 3D printer (LAN/mDNS, root)
alias spr='ssh ssh.praxisweb.xyz'        # pansa via Cloudflare Argo

# --- tmux on the two compute boxes -----------------------------------------
# Attach to `main`, or create it; -t forces a tty for tmux.
alias som='ssh -t omo tmux new -As main'
alias spm='ssh -t pansa tmux new -As main'

# --- plumbing --------------------------------------------------------------
alias sshcfg='$EDITOR ~/.ssh/config'
alias sshlist='grep -E "^Host " ~/.ssh/config | sed "s/^Host //"'
