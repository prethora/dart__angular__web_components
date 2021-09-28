# COLORS
LIGHTGREEN='\033[1;32m'
LIGHTBLUE='\033[1;34m'
LIGHTGREY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

function escapeSed
{
    local VALUE="$1"
    ESCAPED_VALUE="${VALUE//\\/\\\\}"
    ESCAPED_VALUE="${ESCAPED_VALUE//\//\\\/}"
    ESCAPED_VALUE="${ESCAPED_VALUE//&/\\&}"
    echo "$ESCAPED_VALUE"
}

function printAction
{
    local ACTION="$1"
    local NOOUTPUT="$2"
    local TRAILING="\n"
    [[ "$NOOUTPUT" == "1" ]] && TRAILING=""
    echo -e "${LIGHTBLUE}\$ ${ACTION}${NC}${TRAILING}"
}

function printInfo
{
    local INFO="$1"
    local NOOUTPUT="$2"
    local TRAILING="\n"
    [[ "$NOOUTPUT" == "1" ]] && TRAILING=""
    echo -e "${LIGHTBLUE}* ${INFO}${NC}${TRAILING}"
}

function confirm
{
    local QUESTION="$1"
    local DEFAULT="$2"
    [[ -z "$DEFAULT" ]] && DEFAULT="n"
    [[ "$DEFAULT" == "N" ]] && DEFAULT="n"
    [[ "$DEFAULT" == "Y" ]] && DEFAULT="y"
    [[ ! "$DEFAULT" =~ ^[ny]$ ]] && echo "error: confirm: invalid value for DEFAULT parameter, expecting 'n', 'N', 'y' or 'Y'" && exit 1
    local OPTIONS="(y/N)"
    [[ "$DEFAULT" == "y" ]] && OPTIONS="(Y/n)"
    local BREAK="0"
    while [[ "$BREAK" == "0" ]]; do
        printf "${WHITE}$QUESTION${NC} $OPTIONS: "
        read -n 1 -r; [[ ! -z "$REPLY" ]] && echo ""
        if [[ -z "$REPLY" ]]; then
            REPLY="$DEFAULT"
            tput cuu 1
            tput cuf "${#QUESTION}"
            tput cuf "${#OPTIONS}"
            tput cuf 3
            echo "$REPLY"
        fi
        if [[ "$REPLY" =~ ^[nNyY]$ ]]; then
            if [[ "$REPLY" =~ ^[nN]$ ]]; then
                return 1
            else
                BREAK="1"
            fi
        else
            echo " * error: invalid answer"
        fi
    done    
}

function waitContinue
{
    printf "Press any key to continue..."
    read -n 1 -r -s; echo ""
}

function getRandomKey
{
    head /dev/urandom | tr -dc a-zA-Z0-9 | head -c 13
}

TMP_DIR_PATH=""

function createTmpDir
{
    TMP_DIR_PATH="/tmp/$(getRandomKey)"
    mkdir "$TMP_DIR_PATH"
    trap "rm -rf $TMP_DIR_PATH" EXIT
}

EF_REMAINING_ARGS=()
EF_FLAG=0

function extractFlag
{
    local OPTIONS=()
    local ARGS=()
    local SEP_FOUND=0
    for ARG in "$@"; do
        if [[ "$SEP_FOUND" == 1 ]]; then            
            ARGS+=( "$ARG" )
        else
            if [[ "$ARG" == "|" ]]; then
                SEP_FOUND=1
            else
                OPTIONS+=( "$ARG" )
            fi
        fi
    done
    [[ "$SEP_FOUND" == 0 ]] && echo "fatal: extractFlag must be called with the '|' separator between options and arguments" && exit 1
    EF_REMAINING_ARGS=()
    EF_FLAG=0
    for ARG in "${ARGS[@]}"; do
        local FOUND=0
        for OPTION in "${OPTIONS[@]}"; do
            if [[ "$ARG" == "$OPTION" ]]; then
                FOUND=1
                break
            fi
        done
        if [[ "$FOUND" == 1 ]]; then
            EF_FLAG=1
        else
            EF_REMAINING_ARGS+=( "$ARG" )
        fi
    done
}