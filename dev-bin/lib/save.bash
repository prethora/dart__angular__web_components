function _processHelp
{
    if [[ "$#" == 1 ]] && [[ "$1" =~ ^(-h)|(--help)$ ]]; then

cat << EOF
Commit all changes (if any) on the current branch, and push it to origin.

USAGE

  ./dev-bin/save [OPTIONS] [MESSAGE]

ARGUMENTS

  Optionally provide a MESSAGE as a single argument. If omitted, a timestamp of the format
  '%Y-%m-%d-%H-%M' will be used.

OPTIONS

  -f,--force    whether to prefix the current branch with a '+' sign when pushing to origin,
                defaults to false.
  -y,--yes      automatically answer 'y' to all interactive confirmation messages.
  -h,--help     show this help page.

EOF

        exit 0
    fi
}

function _loadArgs
{
    local ARGS=( "$@" )
    
    extractFlag "-f" "--force" "|" "${ARGS[@]}"
    FORCE="$EF_FLAG"
    ARGS=( "${EF_REMAINING_ARGS[@]}" )

    extractFlag "-y" "--yes" "|" "${ARGS[@]}"
    YES="$EF_FLAG"
    ARGS=( "${EF_REMAINING_ARGS[@]}" )

    if [[ "${#ARGS[@]}" -gt 1 ]]; then
        echo "fatal: expecting at most 1 argument"
        exit 1
    elif [[ "${#ARGS[@]}" == 1 ]]; then
        MESSAGE="${ARGS[0]}"
    fi
}