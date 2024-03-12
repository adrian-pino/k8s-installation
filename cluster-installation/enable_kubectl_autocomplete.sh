#!/bin/bash

# Define the lines to be added
LINE1="source <(kubectl completion bash)"
LINE2="alias k=kubectl"
LINE3="complete -o default -F __start_kubectl k"

# File to modify
FILE=~/.bashrc

# Function to add a line if it does not already exist in the file
add_line_if_not_exists() {
  line="$1"
  file="$2"
  grep -qF -- "$line" "$file" || echo "$line" >> "$file"
}

# Add lines to .bashrc if they do not already exist
add_line_if_not_exists "$LINE1" "$FILE"
add_line_if_not_exists "$LINE2" "$FILE"
add_line_if_not_exists "$LINE3" "$FILE"

echo "kubectl completion and alias added to $FILE"

