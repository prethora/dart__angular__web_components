function _processHelp
{
    if [[ "$#" == 1 ]] && [[ "$1" =~ ^(-h)|(--help)$ ]]; then

cat << EOF
Merge the current non-master branch into the master branch as a single commit, and delete
the current branch. Will fail if there are any pending working changes.

USAGE

  ./dev-bin/merge [-y | --yes] [<message>] 
                  -h | --help

ARGUMENTS

  [<message>]    the commit message. Defaults to "merged {branch name}".

  -y,--yes       automatically answer 'y' to all interactive confirmation messages.

  -h,--help      show this help page.

EOF

        exit 0
    fi
}

function _loadArgs
{
    local ARGS=( "$@" )

    extractFlag "-y" "--yes" "|" "${ARGS[@]}"
    YES="$EF_FLAG"
    ARGS=( "${EF_REMAINING_ARGS[@]}" )

    local ARG_COUNT="${#ARGS[@]}"

    [[ "$ARG_COUNT" -gt 1 ]] && echo "fatal: unexpected argument(s) after <message>" && exit 1

    if [[ "$ARG_COUNT" == 1 ]]; then
        MESSAGE="${ARGS[0]}"
    fi
}

function _merge
{
    local CURRENT_BRANCH="$(getCurrentBranch)"
    [[ "$CURRENT_BRANCH" == "master" ]] && echo "fatal: merge only works on non-master branches" && exit 1
    [[ "$CURRENT_BRANCH" == "release" ]] && echo "fatal: cannot merge the release branch" && exit 1    
    isSaveable && echo "fatal: cannot merge a branch with pending working changes" && exit 1

    local CURRENT_COMMIT_ID="$(git rev-parse "$CURRENT_BRANCH")"
    local MASTER_COMMIT_ID="$(git rev-parse master)"

    [[ "$CURRENT_COMMIT_ID" == "$MASTER_COMMIT_ID" ]] && echo "fatal: this branch has not diverged from the master branch - nothing to merge" && exit 1

    [[ -z "$(git branch --contains master "$CURRENT_BRANCH")" ]] && echo "fatal: the master branch is not a parent commit of this branch" && exit 1

    [[ -z "$MESSAGE" ]] && MESSAGE="merged $CURRENT_BRANCH"

    if [[ "$YES" == 1 ]] || confirm "Are you sure you want to merge this branch into the master branch?"; then
        [[ "$YES" != 1 ]] && echo ""

        printAction "git reset --soft master"
        git reset --soft master; ERR="$?";
        [[ "$ERR" != 0 ]] && echo "fatal: 'git reset' failed with exit code $ERR" && exit 1

        printAction "git stash push"
        git stash push; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git stash push' failed with exit code $ERR" && exit 1

        printAction "git checkout master"
        git checkout master; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git checkout' failed with exit code $ERR" && exit 1

        printAction "git stash pop"
        git stash pop; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git stash pop' failed with exit code $ERR" && exit 1

        printAction "git add -A"
        git add -A; ERR="$?"
        [[ "$ERR" != 0 ]] && echo "fatal: 'git add' failed with exit code $ERR" && exit 1

        printAction "git commit -m \"...\""
        git commit -m "$MESSAGE"; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git commit' failed with exit code $ERR" && exit 1

        printAction "git branch -D \"$CURRENT_BRANCH\""
        git branch -D "$CURRENT_BRANCH"; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git branch -D' failed with exit code $ERR" && exit 1

        printAction "git push origin master \":$CURRENT_BRANCH\""
        git push origin master ":$CURRENT_BRANCH"; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git push' failed with exit code $ERR" && exit 1
    fi
}