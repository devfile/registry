#!/bin/bash

diff=$(git diff origin/main HEAD --stat)

changed_stacks=()

if [ "$TEST_ALL_STACKS" == "true" ]; then
  for file in $(find stacks -name devfile.yaml); do
    if [[ $file =~ stacks\/(.*)\/devfile\.yaml ]]; then
      changed_stacks+=(${BASH_REMATCH[1]})
    fi
  done
else
  for file in $diff; do
    if [[ $file =~ stacks\/(.*)\/devfile\.yaml ]]; then
      changed_stacks+=(${BASH_REMATCH[1]})
    fi
  done
fi

echo ${changed_stacks[@]} | tr -d '\n'
