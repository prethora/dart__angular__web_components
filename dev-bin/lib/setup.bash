function _processHelp
{
    if [[ "$#" == 1 ]] && [[ "$1" =~ ^(-h)|(--help)$ ]]; then

cat << EOF
Interactively setup this project.

USAGE

  ./dev-bin/setup [OPTIONS]

OPTIONS

  -y,--yes          automatically answer 'y' to all interactive confirmation messages.
  -a,--all-repos    do not filter the repo address menu.
  -h,--help         show this help page.

EOF

        exit 0
    fi
}

function _isCustomizable
{
    [[ -f "$PUBSPEC_PATH" ]] && 
    [[ "$(cat "$PUBSPEC_PATH")" =~ \{\{name\}\}.*\{\{description\}\} ]] && 
    [[ -f "$WEB_MAIN_PATH" ]] && 
    [[ "$(cat "$WEB_MAIN_PATH")" =~ \{\{name\}\} ]] &&
    [[ -f "$TEST_APP_TEST_PATH" ]] && 
    [[ "$(cat "$TEST_APP_TEST_PATH")" =~ \{\{name\}\} ]] &&
    [[ -f "$WEB_INDEX_PATH" ]] && 
    [[ "$(cat "$WEB_INDEX_PATH")" =~ \{\{title\}\} ]]
}

function _readName
{
    local BREAK="0"
    while [[ "$BREAK" == "0" ]] ; do
        printf "${WHITE}Name${NC}: "
        read -r
        if [[ "$REPLY" =~ ^[[:space:]]*([a-zA-Z][a-zA-Z0-9\_]*)[[:space:]]*$ ]]; then
            NAME="${BASH_REMATCH[1]}"
            BREAK="1"
        else
            echo " * error: invalid name"
        fi
    done
}

function _readDescription
{
    local BREAK="0"
    while [[ "$BREAK" == "0" ]] ; do
        printf "${WHITE}Description${NC}: "
        read -r
        REPLY="$(echo "${REPLY}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [[ ! -z "$REPLY" ]]; then
            DESCRIPTION="$REPLY"
            BREAK="1"
        else
            echo " * error: description cannot be empty"
        fi
    done
}

function _readTitle
{
    local BREAK="0"
    while [[ "$BREAK" == "0" ]] ; do
        printf "${WHITE}Title${NC}: "
        read -r
        REPLY="$(echo "${REPLY}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
        if [[ ! -z "$REPLY" ]]; then
            TITLE="$REPLY"
            BREAK="1"
        else
            echo " * error: title cannot be empty"
        fi
    done
}

function _readRepoAddress
{
    menu ${REPO_ADDRESSES[@]} "(none):" -c "Repo Address" -e
    REPO_ADDRESS="$REPLY"
}

function _replaceTags
{
    local SOURCE_FILE="$PUBSPEC_PATH"
    local SWAP_FILE="$SOURCE_FILE.swap"
    sed "s/{{name}}/$NAME/g; s/{{description}}/$DESCRIPTION/g" "$SOURCE_FILE" > "$SWAP_FILE"
    mv "$SWAP_FILE" "$SOURCE_FILE"

    SOURCE_FILE="$WEB_MAIN_PATH"
    SWAP_FILE="$SOURCE_FILE.swap"
    sed "s/{{name}}/$NAME/g" "$SOURCE_FILE" > "$SWAP_FILE"
    mv "$SWAP_FILE" "$SOURCE_FILE"

    SOURCE_FILE="$TEST_APP_TEST_PATH"
    SWAP_FILE="$SOURCE_FILE.swap"
    sed "s/{{name}}/$NAME/g" "$SOURCE_FILE" > "$SWAP_FILE"
    mv "$SWAP_FILE" "$SOURCE_FILE"

    SOURCE_FILE="$WEB_INDEX_PATH"
    SWAP_FILE="$SOURCE_FILE.swap"
    sed "s/{{title}}/$(escapeSed "$TITLE")/g" "$SOURCE_FILE" > "$SWAP_FILE"
    mv "$SWAP_FILE" "$SOURCE_FILE"

    echo ""
}

function _manageRepo1
{
    rm -rf .git
    if [[ ! -z "$REPO_ADDRESS" ]]; then
        local REPO="$REPO_ADDRESS:$NAME"
        printAction "git init"
        git init; echo ""
        printAction "git remote add origin $REPO"
        git remote add origin "$REPO";
        local GIT_URL="$(git remote get-url origin)"
        if [[ "$GIT_URL" =~ ^git@([a-zA-Z][a-zA-Z0-9\_\-]*)\.github\.com:([a-zA-Z][a-zA-Z0-9\_\-]*\/[a-zA-Z][a-zA-Z0-9\_\-]*)(\.git)?$ ]]; then
            local ACCOUNT_NAME="${BASH_REMATCH[1]}"
            local REPO_NAME="${BASH_REMATCH[2]}"
            if [[ -f ~/.config/gh/accounts/"$ACCOUNT_NAME".yml ]]; then
                if ! repoExists "$ACCOUNT_NAME" "$REPO_NAME" ; then
                    if [[ "$YES" == 1 ]] || confirm "Would you like to create this repo on github.com?" "y"; then
                        local BREAK=0
                        while [[ "$BREAK" == "0" ]]; do
                            if createRepo "$ACCOUNT_NAME" "$REPO_NAME" "$DESCRIPTION" 1; then
                                [[ "$YES" == 1 ]] && printInfo "created remote repo on github.com"
                                REPO_EXISTS=1
                                BREAK="1"
                            else
                                echo " * error: was unable to create repo"
                                if ! confirm "Would you like to retry" "y"; then
                                    BREAK="1"
                                fi
                            fi
                        done
                    fi
                    [[ "$YES" != 1 ]] && echo ""
                else
                    if [[ "$YES" == 1 ]] || confirm "Remote repo already exists, would you like to reset it?" "y"; then
                        silentCleanupRemoteRepo
                        [[ "$YES" == 1 ]] && printInfo "reset existing remote repo on github.com"
                    fi
                    [[ "$YES" != 1 ]] && echo ""
                    REPO_EXISTS=1
                fi                
            fi            
        fi
    fi
}

function _pubGet
{
    printAction "pub get"
    pub get; echo ""
}

function _manageRepo2
{
    if [[ ! -z "$REPO_ADDRESS" ]]; then
        if [[ "$YES" == 1 ]] || confirm "Would you like to create an initial commit for the master branch?" "y"; then
            [[ "$YES" != 1 ]] && echo ""
            printAction "git add -A"
            git add -A
            printAction "git commit -m \"Initial commit\""
            git commit -m "Initial commit"; echo ""
            if [[ "$REPO_EXISTS" == 1 ]]; then
                if [[ "$YES" == 1 ]] || confirm "Would you like to push the initial commit to origin?" "y"; then
                    [[ "$YES" != 1 ]] && echo ""
                    printAction "git push -u origin +master"
                    git push -u origin +master; echo ""
                fi
            else
                echo ""
            fi
        else
            echo ""
        fi
    fi
}

function _loadArgs
{
    local ARGS=( "$@" )
    
    extractFlag "-y" "--yes" "|" "${ARGS[@]}"
    YES="$EF_FLAG"
    ARGS=( "${EF_REMAINING_ARGS[@]}" )

    extractFlag "-a" "--all-repos" "|" "${ARGS[@]}"
    ALL_REPOS="$EF_FLAG"
    ARGS=( "${EF_REMAINING_ARGS[@]}" )

    if [[ "${#ARGS[@]}" -gt 0 ]]; then
        echo "fatal: not expecting any arguments"
        exit 1
    fi
}
