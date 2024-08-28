#!/bin/bash

echo "Executing script on abort ..."

if [ "$OPTIONS" = "DOCKER IMAGE" ] ; then
  echo "Removing docker image: '$TARGET' ..."
  docker image rm "$TARGET"
fi

echo "Abort management script completed!"
