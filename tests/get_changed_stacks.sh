#!/bin/bash

diff=$(git diff origin/main HEAD --stat)

changed_stacks=()

for file in $diff; do
  if [[ $file =~ stacks\/(.*)\/devfile\.yaml ]]; then
    changed_stacks+=(${BASH_REMATCH[1]})
  fi
done

echo ${changed_stacks[@]} | tr -d '\n'
