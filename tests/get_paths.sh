#!/usr/bin/env bash

# Shared utilities for devfile registry test scripts
# Usage: source this file and call set_stack_defaults() after parsing arguments

# Common variables used by all scripts
stackDirs=''
stacksPath=''

# Function to set default values for stack arguments
set_stack_defaults() {
    if [ -z "$stackDirs" ]; then
        stackDirs=$(bash "$(pwd)/tests/get_stacks.sh")
    fi

    if [ -z "$stacksPath" ]; then
        stacksPath="$(pwd)/stacks"
    fi
}

# Helper function to restore positional parameters
restore_positional_args() {
    local -n args_array=$1
    if [ ${#args_array[@]} -gt 0 ]; then
        set -- "${args_array[@]}"
    else
        set --
    fi
} 