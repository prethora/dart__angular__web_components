function getProjectName
{
    [[ ! -f "pubspec.yaml" ]] && echo "fatal: invalid project directory - pubspec.yaml not found" && exit 1
    local PATTERN='\bname:\ *([a-zA-Z0-9\_]+)\b'
    if [[ "$(cat pubspec.yaml)" =~ $PATTERN ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "fatal: invalid project directory - unable to extract name from pubspec.yaml"
        exit 1
    fi
}