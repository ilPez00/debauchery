# arch-omarchy shell — Debian host dotfiles, Arch system info.
# Deployed by scripts/18-arch-shell.sh from this repo file.
#
# The host .zshrc is the single source of truth for aliases, prompt, PATH and
# startup banner. HOME is pointed at the bind-mounted Debian home only while
# sourcing it, so every ~ path resolves exactly as it does on the host. The
# fastfetch/neofetch banner then comes from the container's own /usr/bin, so
# it correctly reports Arch / Omarchy.

export OMARCHY_IN_BOX=1

_DEB_HOME="$HOME"
HOME=/home/gio
if [ -f /home/gio/.zshrc ]; then
  source /home/gio/.zshrc
fi
HOME="$_DEB_HOME"
unset _DEB_HOME

# Arch-only conveniences, defined after the host config so they win.
alias arch='echo "already in the Arch container"'
alias ar='echo "already in the Arch container"'
alias debian='exit'
alias pac='pacman -Q'
alias pacs='pacman -Ss'
alias pacu='pacman -Syu'
alias ap='omarchy-pkg add'
alias ad='omarchy-pkg drop'
alias apres='omarchy-pkg present'
alias amis='omarchy-pkg missing'
alias aa='omarchy-pkg aur-add'
alias ai='omarchy-pkg install'
