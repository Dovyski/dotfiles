#!/usr/bin/env bash
set -euo pipefail

# ubuntu.sh
# Installs Oh My Bash and sets theme to "agnoster"

OMB_INSTALL_URL="https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh"
THEME_NAME="agnoster"

echo "==> Installing Oh My Bash..."

# Install non-interactively (prevents it from dropping you into a new shell)
export OSH="${OSH:-$HOME/.oh-my-bash}"
export OMB_THEME="${OMB_THEME:-$THEME_NAME}"
export OMB_USE_SUDO="${OMB_USE_SUDO:-false}"

# The installer respects "CHSH=no" and "RUNZSH=no" pattern in some frameworks;
# Oh My Bash uses "CHSH" and "RUNBASH" variables.
export CHSH="no"
export RUNBASH="no"

bash -c "$(curl -fsSL "$OMB_INSTALL_URL")"

echo "==> Configuring theme in ~/.bashrc..."

BASHRC="$HOME/.bashrc"
touch "$BASHRC"

# If OSH_THEME is present, replace it. Otherwise, add it.
if grep -qE '^[[:space:]]*OSH_THEME=' "$BASHRC"; then
  sed -i "s/^[[:space:]]*OSH_THEME=.*/OSH_THEME=\"$THEME_NAME\"/" "$BASHRC"
else
  # Place it near the top so it's set before sourcing oh-my-bash (safe either way)
  printf '\n# Oh My Bash theme\nOSH_THEME="%s"\n' "$THEME_NAME" >> "$BASHRC"
fi

# Ensure Oh My Bash is sourced (installer usually adds this, but we harden it)
if ! grep -qE 'oh-my-bash\.sh' "$BASHRC"; then
  cat >> "$BASHRC" <<'EOF'

# Load Oh My Bash
export OSH="$HOME/.oh-my-bash"
source "$OSH/oh-my-bash.sh"
EOF
fi

echo "==> Creating aliases"

cat >> "$BASHRC" <<'EOF'

# Laravel shortcuts
alias a='php artisan'

EOF

echo "==> Done."
echo "Restart your terminal or run: source ~/.bashrc"
