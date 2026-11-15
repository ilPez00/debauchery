# debauchery.zsh — container, package and Omarchy-compat aliases.
# Deployed to ~/.config/debauchery/aliases.zsh by `install.sh` (module: zsh)
# and sourced from ~/.zshrc. Every alias is guarded: nothing here shadows a
# Debian binary and nothing breaks on a box without the container.
#
# Fleet SSH hops stay in ~/.config/fleet/ssh-aliases.zsh — this file does not
# touch them.

# --- debauchery CLI ---------------------------------------------------------
alias deb='~/debauchery/install.sh'
alias debdoc='~/debauchery/install.sh doctor'
alias debst='~/debauchery/install.sh status'

# --- arch container ---------------------------------------------------------
if command -v omarchy-arch >/dev/null 2>&1; then
  alias ar='omarchy-arch'                 # shell inside arch-omarchy
  alias arch='omarchy-arch'
  alias debian='exec $SHELL'            # drop to host (Debian) shell
  alias arb='omarchy-arch --status'       # gateway + container state
  alias aro='omarchy-arch --os'           # prove you are in Arch (uname lies)
  # Debian-first package verbs (apt if a Debian package exists, else container)
  alias ap='omarchy-pkg add'
  alias ad='omarchy-pkg drop'
  alias apres='omarchy-pkg present'
  alias amis='omarchy-pkg missing'
  alias aa='omarchy-pkg aur-add'
  alias ai='omarchy-pkg install'          # fzf picker over Debian packages
  # pacman directly, when the Arch answer is the one you want
  alias pac='pacman -Q'
  alias pacs='pacman -Ss'
  alias pacu='pacman -Syu'
fi

# --- Omarchy compatibility verbs (mapped to DMS / Hyprland) -----------------
if command -v omarchy-menu >/dev/null 2>&1; then
  alias om='omarchy-menu'
  alias omk='omarchy-menu-keybindings'
  alias omshot='omarchy-capture-screenshot'
  alias omlock='omarchy-lock'
  alias omtheme='omarchy-theme-toggle'
fi
