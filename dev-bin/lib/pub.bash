function _processHelp
{
    if [[ "$#" == 1 ]] && [[ "$1" =~ ^(-h)|(--help)$ ]]; then

cat << EOF
Manage releases.

USAGE

  ./dev-bin/pub -t <tag> [-y | --yes]
                ls
                -a <tag> [-y | --yes]
                -h | --help

ARGUMENTS

  -t <tag>     publish the latest commit on the master branch to the release branch, 
               with release tag <tag>, and make it the active release. Will fail if 
               there are any pending working changes.

  -y,--yes     automatically answer 'y' to all interactive confirmation messages.

  ls           list all release tags in reverse chronological order.

  -a <tag>     make <tag> the active release.

  -h,--help    show this help page.

EOF

        exit 0
    fi
}

function _uncacheBuild
{
    local RKEY="$(getRandomKey)"
    local MAIN_JS="build/main.dart.js"
    local MAIN_JS_SWAP="build/main.dart.js.swap"
    local PROJECT_NAME="$(getProjectName)"
    local PACKAGE_DIR_PATH="./build/packages/$PROJECT_NAME"
    local SED_PARTS=()
    local RESOURCE_DIR=""
    if [[ -d "$PACKAGE_DIR_PATH" ]]; then        
        local LINES=()
        local LINE=""
        readarray -t LINES < <( find "$PACKAGE_DIR_PATH" -type d )
        for LINE in "${LINES[@]}"; do
            if [[ "$LINE" =~ ^\.\/build\/(.*\/resources)$ ]]; then                
                RESOURCE_DIR="${BASH_REMATCH[1]}"
                [[ "$RESOURCE_DIR" =~ \/resources\/ ]] && continue
                mv "$LINE" "$LINE.$RKEY"
                local ESCAPED_RESOURCE_DIR="${RESOURCE_DIR//\//\\\/}";
                SED_PARTS+=( "s/\b$ESCAPED_RESOURCE_DIR\b/$ESCAPED_RESOURCE_DIR.$RKEY/g;" )
            fi
        done
        local SED_PATTERN="${SED_PARTS[@]}"
        sed "$SED_PATTERN" "$MAIN_JS" > "$MAIN_JS_SWAP"
        mv "$MAIN_JS_SWAP" "$MAIN_JS"
    fi

    local FAVICON_PATH="build/favicon.png"    
    local MAIN_DART_PATH="build/main.dart.js"
    local STYLES_PATH="build/styles.css"
    local INDEX_PATH="build/index.html"
    local INDEX_SWAP_PATH="build/index.html.swap"
    local HASH_LENGTH=16
    local FAVICON_HASH="$(sha1sum "$FAVICON_PATH" | head -c $HASH_LENGTH)"
    local MAIN_DART_HASH="$(sha1sum "$MAIN_DART_PATH" | head -c $HASH_LENGTH)"
    local STYLES_HASH="$(sha1sum "$STYLES_PATH" | head -c $HASH_LENGTH)"
    local FAVICON_HASHED_FILENAME="favicon.$FAVICON_HASH.png"
    local MAIN_DART_HASHED_FILENAME="main.dart.$MAIN_DART_HASH.js"
    local STYLES_HASHED_FILENAME="styles.$STYLES_HASH.css"
    mv "$FAVICON_PATH" "build/$FAVICON_HASHED_FILENAME"
    mv "$MAIN_DART_PATH" "build/$MAIN_DART_HASHED_FILENAME"
    mv "$STYLES_PATH" "build/$STYLES_HASHED_FILENAME"
    sed "s/\"favicon.png\"/\"$FAVICON_HASHED_FILENAME\"/g; s/\"main.dart.js\"/\"$MAIN_DART_HASHED_FILENAME\"/g; s/\"styles.css\"/\"$STYLES_HASHED_FILENAME\"/g" "$INDEX_PATH" > "$INDEX_SWAP_PATH"
    mv "$INDEX_SWAP_PATH" "$INDEX_PATH"
}

function _build
{
    rm -rf build 2>&1 > /dev/null
    printAction "webdev build"
    webdev build; ERR="$?"; echo ""
    [[ "$ERR" != "0" ]] && echo "fatal: build failed with exit code $ERR" && exit 1
    local PROJECT_NAME="$(getRepoShortName)"
    local INSERT_CODE="  <base href=\"$PROJECT_NAME\" />"
    local INDEX_HTML_PATH="./build/index.html"
    local INDEX_HTML_SWAP_PATH="./build/index.swap.html"
    awk -vvalue="$INSERT_CODE" '
        BEGIN                         {p=1}
        /^  <!-- BASE HREF OPEN  -->\.*$/      {print;print value;p=0}
        /^  <!-- BASE HREF CLOSE  -->\.*$/    {p=1}
        p' "$INDEX_HTML_PATH" > "$INDEX_HTML_SWAP_PATH"
    mv "$INDEX_HTML_SWAP_PATH" "$INDEX_HTML_PATH"
    _uncacheBuild
}

function _commit
{
    local COMMIT_MESSAGE="$1"
    ! createTmpDir && echo "fatal: unable to create tmp directory" && exit 1

    cp -r build "$TMP_DIR_PATH"
    [[ -f "$TMP_DIR_PATH"/build/.packages ]] && rm "$TMP_DIR_PATH"/build/.packages
    [[ -f "$TMP_DIR_PATH"/build/.build.manifest ]] && rm "$TMP_DIR_PATH"/build/.build.manifest
    [[ -d "$TMP_DIR_PATH"/build/.dart_tool ]] && rm -rf "$TMP_DIR_PATH"/build/.dart_tool
    [[ -f .gitignore ]] && cp .gitignore "$TMP_DIR_PATH"

    if doesBranchExist "release"; then
        printAction "git checkout release"
        git checkout release; ERR="$?"; echo ""
    else
        printAction "git checkout --orphan release"
        git checkout --orphan release; ERR="$?"; echo ""
    fi
    [[ "$ERR" != "0" ]] && echo "fatal: 'git checkout' failed with exit code $ERR" && exit 1

    printAction "git rm -rf ."
    git rm -rf .; ERR="$?"; echo ""
    [[ "$ERR" != "0" ]] && echo "fatal: 'git rm' failed with exit code $ERR" && exit 1

    cp -r "$TMP_DIR_PATH"/build/. .
    [[ -f "$TMP_DIR_PATH"/.gitignore ]] && cp "$TMP_DIR_PATH"/.gitignore .
    echo "ignore: output to make sure there is a difference from the last commit." > "./diff.$(getRandomKey)"

    printAction "git add -A"
    git add -A; ERR="$?"
    [[ "$ERR" != "0" ]] && echo "fatal: 'git add' failed with exit code $ERR" && exit 1

    printAction "git commit -m \"...\""
    git commit -m "$COMMIT_MESSAGE"; ERR="$?"; echo ""
    [[ "$ERR" != "0" ]] && echo "fatal: 'git commit' failed with exit code $ERR" && exit 1

    printAction "git tag -a \"release_tag_$TAG\" -m \"release_tag_$TAG\""
    git tag -a "release_tag_$TAG" -m "release_tag_$TAG"; ERR="$?"
    [[ "$ERR" != "0" ]] && echo "fatal: 'git tag -a' failed with exit code $ERR" && exit 1

    if doesBranchExist "gh-pages"; then
        printAction "git branch -D gh-pages"
        git branch -D gh-pages; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git branch -D' failed with exit code: $ERR" && exit 1
    fi

    printAction "git checkout -b gh-pages"
    git checkout -b "gh-pages"; ERR="$?"; echo ""
    [[ "$ERR" != 0 ]] && echo "fatal: 'git checkout' failed with exit code: $ERR" && exit 1

    printAction "git push -u origin release release_tag_$TAG +gh-pages"
    git push -u origin release release_tag_$TAG +gh-pages; ERR="$?"; echo ""
    [[ "$ERR" != "0" ]] && echo "fatal: 'git push' failed with exit code $ERR" && exit 1

    printAction "git checkout master"
    git checkout master; ERR="$?"; echo ""
    [[ "$ERR" != "0" ]] && echo "fatal: 'git checkout' failed with exit code $ERR" && exit 1

    rm -rf build
}

function _loadArgs
{
    local ARGS=( "$@" )

    extractFlag "-y" "--yes" "|" "${ARGS[@]}"
    YES="$EF_FLAG"
    ARGS=( "${EF_REMAINING_ARGS[@]}" )

    local ARG_COUNT="${#ARGS[@]}"

    if [[ "${ARGS[0]}" == "-t" ]]; then
        [[ "$ARG_COUNT" -gt 2 ]] && echo "fatal: unexpected argument(s) after <tag>" && exit 1
        [[ "$ARG_COUNT" == 1 ]] && echo "fatal: <tag> is required" && exit 1

        TAG="${ARGS[1]}"
        if [[ ! "$TAG" =~ ^[a-zA-Z0-9\.\_\-]+$ ]]; then
            echo "fatal: invalid tag, accepted characters: a-z, A-Z, 0-9, '.', '_' and '-'"
            exit 1
        fi

        COMMAND="publish"
    elif [[ "${ARGS[0]}" == "ls" ]]; then
        [[ "$YES" == 1 ]] && echo "fatal: the -u command does not support the --yes flag" && exit 1
        [[ "$ARG_COUNT" -gt 1 ]] && echo "fatal: the ls command does not take any arguments" && exit 1

        COMMAND="list"
    elif [[ "${ARGS[0]}" == "-a" ]]; then
        [[ "$ARG_COUNT" -gt 2 ]] && echo "fatal: unexpected argument(s) after <tag>" && exit 1
        [[ "$ARG_COUNT" == 1 ]] && echo "fatal: <tag> is required" && exit 1

        TAG="${ARGS[1]}"
        if [[ ! "$TAG" =~ ^[a-zA-Z0-9\.\_\-]+$ ]]; then
            echo "fatal: invalid tag, accepted characters: a-z, A-Z, 0-9, '.', '_' and '-'"
            exit 1
        fi

        COMMAND="activate"
    elif [[ "$ARG_COUNT" == 1 ]]; then
        echo "fatal: unrecognized command '${ARGS[0]}'"
        exit 1
    else
        echo "fatal: expecting a command"
        exit 1
    fi
}

function _printUrl
{
    echo -e "--------------------\n\n${WHITE}[url]${NC} $(getGhPagesUrl)\n"
}

function _publish
{
    local CURRENT_BRANCH="$(getCurrentBranch)"
    [[ "$CURRENT_BRANCH" != "master" ]] && echo "fatal: can only publish from the master branch" && exit 1

    local MASTER_COMMIT_COUNT=$(getCommitCount "master")
    [[ "$MASTER_COMMIT_COUNT" == 0 ]] && echo "fatal: the master branch must be saved before being published" && exit 1

    isSaveable && echo -e "fatal: you cannot publish the master branch with working changes - save it first, or run \`git stash push -u\` \nto stash the changes and run \`git stash pop\` after publishing to restore them." && exit 1

    local LAST_RELEASE_COMMIT=$(getLastCommitMessage "release")
    local LAST_RELEASE_MASTER_COMMIT_ID=""
    [[ "$LAST_RELEASE_COMMIT" =~ ^[0-9a-f]+ ]] && LAST_RELEASE_MASTER_COMMIT_ID="${BASH_REMATCH[0]}"
    local CURRENT_MASTER_COMMIT_ID="$(getHeadCommitId)"
    [[ "$CURRENT_MASTER_COMMIT_ID" == "$LAST_RELEASE_MASTER_COMMIT_ID" ]] && echo "fatal: this master branch commit has already been published" && exit 1

    [[ "$TAG" == "latest" ]] && echo "fatal: <tag> cannot be the reserved keyword 'latest'" && exit 1

    if releaseTagExists "$TAG"; then
        echo "fatal: this release tag is already in use"
        exit 1
    fi

    if [[ "$YES" == 1 ]] || confirm "Are you sure you want to publish to the release branch?"; then
        [[ "$YES" != 1 ]] && echo ""
        _build && \
        _commit "$CURRENT_MASTER_COMMIT_ID - $TAG" && \
        _printUrl
    fi
}

function _list
{
    local LINES=()
    local LINES=""
    readarray -t LINES < <( git log --format='%D' release 2>&1 )
    local PATTERN1='\btag: release_tag_([a-zA-Z0-9\.\_\-]+)'
    local PATTERN2='\bgh-pages\b'
    for LINE in "${LINES[@]}"; do
        if [[ "$LINE" =~ $PATTERN1 ]]; then
            local TAG="${BASH_REMATCH[1]}"
            if [[ "$LINE" =~ $PATTERN2 ]]; then
                echo -e "* ${LIGHTGREEN}$TAG${NC}"
            else
                echo "  $TAG"
            fi
        fi        
    done
}

function _activate
{    
    local STASHED=0
    local _TAG="$TAG"
    
    local CURRENT_BRANCH="$(getCurrentBranch)"
    [[ "$CURRENT_BRANCH" != "master" ]] && echo "fatal: can only activate a release from the master branch" && exit 1

    local ACTIVE_RELEASE_TAG="$(getActiveReleaseTag)"
    [[ -z "$ACTIVE_RELEASE_TAG" ]] && echo "fatal: there are no releases yet" && exit 1
    [[ "$_TAG" == "latest" ]] && _TAG="$(getLatestReleaseTag)"
    [[ "$_TAG" == "$ACTIVE_RELEASE_TAG" ]] && echo "fatal: release is already active" && exit 1    

    local FULL_TAG="release_tag_$_TAG"

    ! refExists "$FULL_TAG" && echo "fatal: release tag does not exist" && exit 1

    if [[ "$YES" == 1 ]] || confirm "Are you sure you want to activate release '$_TAG'?"; then
        [[ "$YES" != 1 ]] && echo ""

        if isSaveable; then
            git stash push -u >/dev/null 2>&1; ERR="$?";
            [[ "$ERR" != 0 ]] && echo "fatal: 'git stash push' failed with exit code: $ERR" && exit 1
            STASHED=1
        fi

        if doesBranchExist "gh-pages"; then
            printAction "git branch -D gh-pages"
            git branch -D gh-pages; ERR="$?"; echo ""
            [[ "$ERR" != 0 ]] && echo "fatal: 'git branch -D' failed with exit code: $ERR" && exit 1
        fi

        printAction "git checkout $FULL_TAG"
        git checkout "$FULL_TAG"; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git checkout' failed with exit code: $ERR" && exit 1

        printAction "git checkout -b gh-pages"
        git checkout -b "gh-pages"; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git checkout' failed with exit code: $ERR" && exit 1

        printAction "git push -u origin +gh-pages"
        git push -u origin +gh-pages; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git push' failed with exit code: $ERR" && exit 1

        printAction "git checkout master"
        git checkout master; ERR="$?"; echo ""
        [[ "$ERR" != 0 ]] && echo "fatal: 'git checkout' failed with exit code: $ERR" && exit 1

        if [[ "$STASHED" == 1 ]]; then
            git stash pop >/dev/null 2>&1; ERR="$?";
            [[ "$ERR" != 0 ]] && echo "fatal: 'git stash pop' failed with exit code: $ERR" && exit 1
        fi
    fi
}