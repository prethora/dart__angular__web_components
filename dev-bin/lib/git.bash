function repoExists
{
    local ACCOUNT_NAME="$1"
    local REPO_NAME="$2"
    GH_ACCOUNT="$ACCOUNT_NAME" gh repo view "$REPO_NAME" >/dev/null 2>&1
}

function createRepo
{
    local ACCOUNT_NAME="$1"
    local REPO_NAME="$2"
    local DESCRIPTION="$3"
    local IS_PUBLIC="$4"
    local PUBLIC=""
    [[ "$IS_PUBLIC" == 1 ]] && PUBLIC="--public"
    GH_ACCOUNT="$ACCOUNT_NAME" gh repo create -d "$DESCRIPTION" "$REPO_NAME" "$PUBLIC" >/dev/null 2>&1
    repoExists "$ACCOUNT_NAME" "$REPO_NAME"
}

function getRepoAddresses
{
    local POSTFIX_FILTER="$1"
    local GITCONFIG_FILE_PATH=~/.gitconfig
    [[ ! -f "$GITCONFIG_FILE_PATH" ]] && return 0
    local CONTENT=$(cat "$GITCONFIG_FILE_PATH")
    local PATTERN='\[[[:space:]]*url[[:space:]]+['"'"'"]?[^'"'"'"]*['"'"'"]?[[:space:]]*\][[:space:]]+insteadOf[[:space:]]*=[[:space:]]*([^:]*):(.*)'
    local BREAK=0
    while [[ "$BREAK" == 0 ]]; do
        if [[ "$CONTENT" =~ $PATTERN ]]; then
            local MATCH="${BASH_REMATCH[1]}"
            CONTENT="${BASH_REMATCH[2]}"
            if [[ ! -z "$POSTFIX_FILTER" ]]; then
               local PATTERN2="^.+${POSTFIX_FILTER//\./\\\.}\$" 
               [[ "$MATCH" =~ $PATTERN2 ]] && echo "$MATCH"
            else
                echo "$MATCH"
            fi                        
        else
            BREAK=1
        fi
    done
}

function isSaveable
{
    [[ ! -z "$(git status -s)" ]]
}

function getCurrentBranch
{
    git symbolic-ref --short HEAD
}

function doesBranchExist
{
    local BRANCH_NAME="$1"
    [[ ! -z "$(git branch --list "$BRANCH_NAME")" ]]
}

function getLastCommitMessage
{
    local BRANCH_NAME="$1"
    doesBranchExist "$BRANCH_NAME" && git log -1  --pretty='%s' "$BRANCH_NAME"
}

function getRepoShortName
{
    [[ "$(git remote get-url origin)" =~ \/([^\/\.]+)(\.git)?$ ]] && echo "${BASH_REMATCH[1]}"
}

function getAccountName
{
    [[ "$(git remote get-url origin)" =~ :([^\/]+)\/[^\/\.]+(\.git)?$ ]] && echo "${BASH_REMATCH[1]}"
}

function getGhPagesUrl
{
    echo "https://$(getAccountName).github.io/$(getRepoShortName)/"
}

function getCommitCount
{
    local BRANCH_NAME="$1"
    local RET="$(git rev-list --count "$BRANCH_NAME" 2>&1)"
    if [[ "$RET" =~ ^[0-9]+$ ]]; then
        echo "$RET"
    else
        echo "0"
    fi
}

function listRemoteRefs
{
    git ls-remote -ht origin | while read a b; do echo "$b"; done
}

function silentCleanupRemoteRepo
{
    local REFS=( $(listRemoteRefs) )
    local TODELETE=()
    for REF in "${REFS[@]}"; do
        if [[ "$REF" =~ ^refs\/heads\/(.+)$ ]]; then
            local POSSIBLE_REF="${BASH_REMATCH[1]}"
            [[ "$POSSIBLE_REF" != "master" ]] &&  TODELETE+=( ":${BASH_REMATCH[1]}" )
        elif [[ "$REF" =~ ^refs\/tags\/(.+)$ ]]; then
            local POSSIBLE_REF="${BASH_REMATCH[1]}"
            [[ ! "$POSSIBLE_REF" =~ \^\{\}$ ]] && TODELETE+=( ":$POSSIBLE_REF" )
        fi
    done
    git push origin "${TODELETE[@]}" > /dev/null 2>&1
}

function releaseTagExists
{
    local LOOKUP="$1"
    local TAGS=( $(git tag) )
    local TAG=""
    for TAG in "${TAGS[@]}"; do
        if [[ "$TAG" =~ ^release_tag_([a-zA-Z0-9\.\_\-]+)$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$LOOKUP" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

function getHeadCommitId
{
    git rev-parse HEAD
}

function getLatestReleaseTag
{
    local OUTPUT="$(git log --format='%D' release 2>&1)"
    local PATTERN='\btag:\ release_tag_([a-zA-Z0-9\.\_\-]+)'
    [[ "$OUTPUT" =~ $PATTERN ]] && echo "${BASH_REMATCH[1]}"
}

function getActiveReleaseTag
{    
    local LINES=()
    local LINE=""
    readarray -t LINES < <( git log --format='%D' release 2>&1 )
    local PATTERN1='\btag: release_tag_([a-zA-Z0-9\.\_\-]+)'
    local PATTERN2='\bgh-pages\b'
    for LINE in "${LINES[@]}"; do
        if [[ "$LINE" =~ $PATTERN1 ]]; then
            local TAG="${BASH_REMATCH[1]}"
            if [[ "$LINE" =~ $PATTERN2 ]]; then
                echo "$TAG"
                return 0
            fi
        fi        
    done
}

function refExists
{
    local REF="$1"
    git rev-parse "$REF" >/dev/null 2>&1
}
