# Laravel shortcuts
alias a='php artisan'

# Git worktree for issue, usage like:
#
# ```bash
#  w 1234 add user login
# ```
#
# creates a worktree in ../repo-name-1234-add-user-login
# and a branch named 1234-add-user-login. It can also just be
# called with the issue number only:
#
# ```bash
#  w 1234
# ```
#
# creates ../repo-name-1234 and branch 1234
# --- w: create git worktree from current repo and cd into it ---
w() {
    # Help
    if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" || "$1" == "help" ]]; then
        echo ""
        echo "Usage:"
        echo "  w <ISSUE> [description words...]"
        echo ""
        echo "Examples:"
        echo "  w 45"
        echo "    -> branch: 45"
        echo "    -> worktree: ../<repo>-45"
        echo ""
        echo "  w 45 tweak google columns"
        echo "    -> branch: 45-tweak-google-columns"
        echo "    -> worktree: ../<repo>-45-tweak-google-columns"
        echo ""
        echo "Notes:"
        echo "  - Run inside a git repository"
        echo "  - Description is converted to kebab-case"
        echo ""
        return 0
    fi

    ISSUE="$1"
    shift

    if ! [[ "$ISSUE" =~ ^[0-9]+$ ]]; then
        echo "Error: ISSUE must be numeric."
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not inside a git repository."
        return 1
    fi

    REPO_NAME="$(basename "$(pwd)")"

    # Build kebab-case description if provided
    if [[ $# -gt 0 ]]; then
        DESC="$(printf '%s ' "$@" \
            | tr '[:upper:]' '[:lower:]' \
            | sed -E 's/[^a-z0-9 ]//g; s/ +/-/g; s/-+$//')"
    else
        DESC=""
    fi

    if [[ -n "$DESC" ]]; then
        BRANCH="${ISSUE}-${DESC}"
        WORKTREE="../${REPO_NAME}-${ISSUE}-${DESC}"
    else
        BRANCH="${ISSUE}"
        WORKTREE="../${REPO_NAME}-${ISSUE}"
    fi

    echo "Creating worktree:"
    echo "  Branch : $BRANCH"
    echo "  Path   : $WORKTREE"

    git worktree add "$WORKTREE" -b "$BRANCH" || return 1
    cd "$WORKTREE" || return 1
}

# Git worktree remove for current folder, with confirmation
# Usage:
#
# ```bash
#  wr
# ```
# This command is the counterpart to `w`, removing the current
# worktree after user confirmation. It prevents removing the main
# worktree by mistake.
wr() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not inside a git repository."
        return 1
    fi

    CURRENT_PATH="$(cd "$(pwd)" && pwd)"

    MAIN_WORKTREE="$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')"
    if [[ -z "$MAIN_WORKTREE" ]]; then
        echo "Error: Unable to determine main worktree."
        return 1
    fi
    MAIN_WORKTREE="$(cd "$MAIN_WORKTREE" && pwd)"

    if [[ "$CURRENT_PATH" == "$MAIN_WORKTREE" ]]; then
        echo "Error: You are in the main worktree. Aborting."
        return 1
    fi

    echo ""
    echo "You are about to remove this worktree:"
    echo "  $CURRENT_PATH"
    echo ""
    read -r -p "Type YES to confirm: " CONFIRM

    if [[ "$CONFIRM" != "YES" ]]; then
        echo "Aborted."
        return 0
    fi

    cd "$MAIN_WORKTREE" || return 1
    git worktree remove "$CURRENT_PATH" || return 1

    echo ""
    echo "Worktree removed successfully."
    echo "Now in:"
    echo "  $MAIN_WORKTREE"
}
