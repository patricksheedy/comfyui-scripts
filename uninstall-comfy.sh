#!/bin/bash

INSTALLS_DIR="$HOME/apps/comfy/installs"

if [ $# -eq 0 ]; then
    if [ ! -d "$INSTALLS_DIR" ]; then
        echo "Install directory not found: $INSTALLS_DIR"
        exit 1
    fi

    dirs=()
    while IFS= read -r d; do
        [ -d "$INSTALLS_DIR/$d" ] && dirs+=("$d")
    done < <(ls -1 "$INSTALLS_DIR" 2>/dev/null | sort)

    if [ ${#dirs[@]} -le 1 ]; then
        echo "No directories found to remove: $INSTALLS_DIR"
        exit 1
    fi

    most_recent="${dirs[${#dirs[@]}-1]}"
    to_remove=()
    for d in "${dirs[@]}"; do
        [ "$d" != "$most_recent" ] && to_remove+=("$d")
    done

    echo "Remove these installs?"
    for d in "${to_remove[@]}"; do
        echo "  $INSTALLS_DIR/$d"
    done
    echo ""
    echo "This will be kept:"
    echo "$INSTALLS_DIR/$most_recent"
    echo ""
    echo -n "Press Enter to remove, Ctrl-C to cancel... "
    read -r

    set -- "${to_remove[@]}"
fi

for VERSION in "$@"
do
  CONDA_ENV="comfy-$VERSION"
  WORKSPACE="$INSTALLS_DIR/$VERSION"

  echo "Removing Conda: $CONDA_ENV"
  conda env remove -y -n "$CONDA_ENV"

  echo "Removing Workspace: $WORKSPACE"
  rm -rf "$WORKSPACE"

  echo ""
done

echo "Done!"