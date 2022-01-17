#!/bin/bash

function retry {
  local n=1
  local max=5
  local delay=1
  while true; do
    $(eval $1>&2)
    return_value=$?
    if [ $return_value != 0 ]; then
      if [[ $n -lt $max ]]; then
        echo "-- Step failed. Attempt $n/$max:"
        ((n++))
        sleep $delay;
      else
        echo "-- Step failed after $n attempts. Quitting."
        return $return_value
      fi
    else
      return $?
    fi
  done
}

retry $1
