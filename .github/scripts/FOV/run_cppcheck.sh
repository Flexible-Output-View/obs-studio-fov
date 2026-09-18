#!/bin/bash

# Get changed C/C++ files from git diff
files=$(git diff --name-only HEAD~1 | grep -E '\.(c|cpp|hpp|cxx|h)$')

# Exit early if no relevant files changed
if [ -z "$files" ]; then
  echo "No relevant C/C++ files changed."
  exit 0
fi

# Build an array of --file-filter arguments
filter_args=()
for file in $files; do
  filter_args+=("--file-filter=$file")
done

# Run cppcheck and capture output (stdout and stderr)
cppcheck_output=$(cppcheck \
  --enable=all \
  --quiet \
  --check-level=exhaustive \
  --suppress=missingIncludeSystem \
  --suppress=missingInclude \
  --suppress=unusedFunction \
  --suppress=preprocessorErrorDirective \
  --suppress=unmatchedSuppression \
  --suppress=checkersReport \
  --project=build/compile_commands.json \
  "${filter_args[@]}" 2>&1)
cppcheck_exit_code=$?

# Filter output to only keep lines starting with one of the changed files
filtered_output=""
while IFS= read -r line; do
  for file in $files; do
    if [[ "$line" == "$file":* ]]; then
      filtered_output+="$line"$'\n'
      break
    fi
  done
done <<< "$cppcheck_output"

touch check.txt

# Display filtered results if any exist
if [ -n "$filtered_output" ]; then
  echo -e "$filtered_output" >> check.txt
fi

cat check.txt

exit $cppcheck_exit_code