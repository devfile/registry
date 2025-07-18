#!/usr/bin/env bash

# Common variables used by all scripts
stackDirs=''
stacksPath=''
POSITIONAL_ARGS=()

# Function to parse all arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --stackDirs)
                if [ -z "${stackDirs}" ]; then
                    stackDirs=$2
                else
                    stackDirs="${stackDirs} $2"
                fi
                shift # past argument
                shift
                ;;
            --stacksPath)
                stacksPath=$2
                shift # past argument
                shift
                ;;
            -*|--*)
                # Try script-specific handler if it exists
                local consumed=0
                local errno=1
                if declare -f handle_additional_args > /dev/null 2>&1; then
                    consumed=$(handle_additional_args "$@")
                    errno=$?
                fi
                
                if [ $errno -eq 0 ] && [ $consumed -gt 0 ]; then
                    # Script handler consumed some arguments
                    for ((i=0; i<consumed; i++)); do
                        shift
                    done
                else
                    echo "Unknown option $1"
                    return $errno
                fi
                ;;
            *)
                POSITIONAL_ARGS+=("$1") # save positional arg
                shift # past argument
                ;;
        esac
    done
    
    return 0
}

# Function to set default values for stack arguments
set_stack_defaults() {
    if [ -z "$stackDirs" ]; then
        stackDirs=$(bash "$(pwd)/tests/get_stacks.sh")
    fi

    if [ -z "$stacksPath" ]; then
        stacksPath="$(pwd)/stacks"
    fi
}
