CURSOR_HIDDEN=0

# Used as an exit trap after hiding the cursur with `tput civis`
function _assureCursorShowing
{
    [[ "$CURSOR_HIDDEN" == "1" ]] && tput cnorm
}

# Prints out the length of the longest argument.
function _getLongest
{
    local ARGS=( $@ )
    local RET=0
    for ARG in "${ARGS[@]}"; do
        local LENGTH="${#ARG}"
        [[ "$LENGTH" -gt "$RET" ]] && RET="$LENGTH"
    done
    echo "$RET"
}

# Prints out [COUNT] number of spaces.
function _getSpaces
{
    local COUNT="$1"
    printf '%*s' "$COUNT"
}

# Prints [VALUE] [ALIGN]ed in a frame of virtual [WIDTH] with [PADDING] spaces on both sides.
# Will print out trailing spaces as well so that [WIDTH] characters are printed in any case.
function _alignText
{
    local VALUE="$1"
    local WIDTH="$2"
    local PADDING="$3"
    local ALIGN="$4" # can be 'left','center' or 'right'
    local LENGTH="${#VALUE}"
    local LEADING_SPACES=0
    local TRAILING_SPACES=0
    case "$ALIGN" in 
        "left")
            LEADING_SPACES="$PADDING"
            let TRAILING_SPACES="(${WIDTH}-${LENGTH})-${LEADING_SPACES}"
            ;;
        "center") 
            let LEADING_SPACES="(${WIDTH}-${LENGTH})/2"
            let TRAILING_SPACES="(${WIDTH}-${LENGTH})-${LEADING_SPACES}"
            ;;
        "right") 
            TRAILING_SPACES="$PADDING"
            let LEADING_SPACES="(${WIDTH}-${LENGTH})-${TRAILING_SPACES}"
            ;;
    esac    
    LEADING_SPACES="$(_getSpaces "$LEADING_SPACES")"
    TRAILING_SPACES="$(_getSpaces "$TRAILING_SPACES")"
    echo "${LEADING_SPACES}${VALUE}${TRAILING_SPACES}"
}

# Awaits a single expected key press and prints a representation of it.
# Expected keys: UP, DOWN, ENTER or ESC.
function _readKeyPress
{
    local ESCAPE_CHAR="$(printf "\u1b")"
    local BREAK=0    
    while [[ "$BREAK" == "0" ]]; do
        read -rsn1
        if [[ "$REPLY" == "$ESCAPE_CHAR" ]]; then
            read -rsn2 -t 0.0001
            [[ -z "$REPLY" ]] && REPLY="$ESCAPE_CHAR"
        fi
        case "$REPLY" in        
            "") echo "ENTER"; BREAK=1 ;;
            "$ESCAPE_CHAR") echo "ESC"; BREAK=1 ;;
            "[A") echo "UP"; BREAK=1 ;;
            "[B") echo "DOWN"; BREAK=1 ;;
        esac
    done
}

# Creates an interactive menu on the command line.
#
# Usage:
#   menu [OPTIONS] [item1] [item2]...
#
# Items:
#   Should be provided in the format <DISPLAY>:<ID> or just <DISPLAY> if the <ID> 
#   and <DISPLAY> are the same.
#
# Return value:
#  
#   Will store the <ID> of the selected item in the REPLY variable. If the --escapable
#   flag is set and the ESC key is pressed, the REPLY variable will be empty.
#
# Options:
#   -w,--width         The width of the menu - defaults to the length of the longest item
#                      plus padding on both sides.
#   -p,--padding       The padding on both sides - defaults to 2.
#   -a,--align         The alignment of the item text - defaults to "center"
#                      [left,center,right]
#   -e,--escapable     Whether pressing the ESC key causes the menu to close with a return
#                      value of "" - defaults to false.
#   -c,--caption       If provided, a prompt with this value followed by the ":" character
#                      will be printed on the line above the menu. When the menu closes,
#                      the return value will be printed on the same line after the ":"
#                      character, separated by a space.
#   -d,--dont-clear    Whether to keep the menu on the screen after it closes. By default
#                      the menu is cleared.
#   
function menu
{
    local ARGS=( "$@" )

    local WIDTH=0
    local PADDING=2
    local ALIGN="center"
    local ESCAPABLE=0
    local CAPTION=""
    local DONTCLEAR=0

    local ITEMS=()
    local ITEM_IDS=()

    local CURRENT_PARAM=""
    for ARG in "${ARGS[@]}"; do
        if [[ ! -z "$CURRENT_PARAM" ]]; then
            if [[ "$CURRENT_PARAM" == "width" ]]; then
                WIDTH="$ARG"
            elif [[ "$CURRENT_PARAM" == "padding" ]]; then
                PADDING="$ARG"
            elif [[ "$CURRENT_PARAM" == "align" ]]; then
                ALIGN="$ARG"
            elif [[ "$CURRENT_PARAM" == "caption" ]]; then
                CAPTION="$ARG"
            fi
            CURRENT_PARAM=""
        else
            if [[ "$ARG" == "-w" ]] || [[ "$ARG" == "--width" ]]; then
                CURRENT_PARAM="width"
            elif [[ "$ARG" =~ ^--width=(.*)$ ]]; then
                WIDTH="${BASH_REMATCH[1]}"
            elif [[ "$ARG" == "-p" ]] || [[ "$ARG" == "--padding" ]]; then
                CURRENT_PARAM="padding"
            elif [[ "$ARG" =~ ^--padding=(.*)$ ]]; then
                PADDING="${BASH_REMATCH[1]}"
            elif [[ "$ARG" == "-a" ]] || [[ "$ARG" == "--align" ]]; then
                CURRENT_PARAM="align"
            elif [[ "$ARG" =~ ^--align=(.*)$ ]]; then
                ALIGN="${BASH_REMATCH[1]}"
            elif [[ "$ARG" == "-e" ]] || [[ "$ARG" == "--escapable" ]]; then
                ESCAPABLE=1
            elif [[ "$ARG" == "-c" ]] || [[ "$ARG" == "--caption" ]]; then
                CURRENT_PARAM="caption"
            elif [[ "$ARG" =~ ^--caption=(.*)$ ]]; then
                CAPTION="${BASH_REMATCH[1]}"
            elif [[ "$ARG" == "-d" ]] || [[ "$ARG" == "--dont-clear" ]]; then
                DONTCLEAR=1
            else
                local ITEM="$ARG"
                local ID="$ARG"
                [[ "$ARG" =~ ^([^:]*):([^:]*)$ ]] && ITEM="${BASH_REMATCH[1]}" && ID="${BASH_REMATCH[2]}"
                ITEMS+=( "$ITEM" )
                ITEM_IDS+=( "$ID" )
            fi            
        fi
    done
    [[ ! "$WIDTH" =~ ^[0-9]+$ ]] && echo "error: --width must be an integer" && exit 1
    [[ ! "$PADDING" =~ ^[0-9]+$ ]] && echo "error: --padding must be an integer" && exit 1
    [[ ! "$ALIGN" =~ ^(left)|(center)|(right)$ ]] && echo "error: --align can only be 'left','center' or 'right'" && exit 1
    [[ ! -z "$CURRENT_PARAM" ]] && echo "error: expecting value for --$CURRENT_PARAM" && exit 1    

    tput civis
    CURSOR_HIDDEN=1

    if [[ ! -z "$CAPTION" ]]; then
        echo -e "$(tput setaf 7)$(tput bold)${CAPTION}$(tput sgr 0):"
    fi
    
    local LONGEST="$(_getLongest "${ITEMS[@]}")"
    local NATURAL_WIDTH="$LONGEST"
    let NATURAL_WIDTH="$NATURAL_WIDTH"+"$PADDING"+"$PADDING"
    [[ "$WIDTH" -lt "$NATURAL_WIDTH" ]] && WIDTH="$NATURAL_WIDTH"
    local INDEX=0    
    local BREAK=0
    local ITEM_COUNT="${#ITEMS[@]}"    
    trap _assureCursorShowing EXIT

    for I in $(seq 1 "$ITEM_COUNT"); do
        echo "$(_getSpaces "$WIDTH")"
    done        
    tput cuu "$ITEM_COUNT"

    while [[ "$BREAK" == "0" ]]; do
        for I in "${!ITEMS[@]}"; do
            local CENTERED_TEXT="$(_alignText "${ITEMS[$I]}" "$WIDTH" "$PADDING" "$ALIGN")"
            if [[ "$I" == "$INDEX" ]]; then
                echo "$(tput setab 7)$(tput setaf 0)${CENTERED_TEXT}$(tput sgr 0)"
            else
                echo "$CENTERED_TEXT"
            fi        
        done
        local COMMAND="$(_readKeyPress)"
        case "$COMMAND" in 
            "UP") 
                let INDEX="${INDEX}-1"
                [[ "$INDEX" == "-1" ]] && let INDEX="${ITEM_COUNT}-1"
                ;;
            "DOWN") 
                let INDEX="$INDEX+1"
                [[ "$INDEX" == "$ITEM_COUNT" ]] && INDEX=0
                ;;
            "ENTER") 
                BREAK=1
                ;;
            "ESC") 
                [[ "$ESCAPABLE" == "1" ]] && BREAK=1 && INDEX="-1"
                ;;
        esac
        [[ "$BREAK" == "0" ]] && tput cuu "$ITEM_COUNT"
    done

    if [[ "$INDEX" != "-1" ]]; then
        REPLY="${ITEM_IDS[$INDEX]}"
    else
        REPLY=""
    fi

    if [[ ! -z "$CAPTION" ]]; then
        if [[ "$DONTCLEAR" == "0" ]]; then
            tput cuu "$ITEM_COUNT"
            for I in $(seq 1 "$ITEM_COUNT"); do
                echo "$(_getSpaces "$WIDTH")"
            done        
        fi
        tput cuu "$ITEM_COUNT"
        tput cuu 1
        tput cuf ${#CAPTION} 
        tput cuf 2
        echo "$REPLY"
        if [[ "$DONTCLEAR" == "1" ]]; then
            tput cud "${ITEM_COUNT}"
        fi
    elif [[ "$DONTCLEAR" == "0" ]]; then
        tput cuu "$ITEM_COUNT"
        for I in $(seq 1 "$ITEM_COUNT"); do
            echo "$(_getSpaces "$WIDTH")"
        done
        tput cuu "$ITEM_COUNT"
    fi

    tput cnorm    
    CURSOR_HIDDEN=0
}