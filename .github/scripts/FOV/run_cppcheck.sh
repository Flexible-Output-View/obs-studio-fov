#!/bin/bash

if [ -n "$GITHUB_BASE_REF" ]; then
  base="HEAD^1"
  echo "Running in Pull Request mode (comparing against base: HEAD^1)"
else
  base="HEAD~1"
  echo "Running in standard push mode (comparing against: HEAD~1)"
fi

# Get changed C/C++ files from git diff
files=$(git diff --name-only "$base" HEAD | grep -E '\.(c|cpp|hpp|cxx|h)$')

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

# Prepare check.txt
> check.txt

has_error_or_warning=0

# Process filtered results
if [ -n "$filtered_output" ]; then
  echo -e "$filtered_output" >> check.txt

  # Check if any filtered line contains an error or warning severity
  while IFS= read -r line; do
    if [[ "$line" == *": error:"* ]] || [[ "$line" == *": warning:"* ]]; then
      has_error_or_warning=1
    fi
  done <<< "$filtered_output"
fi

cat check.txt

# Exit with failure (1) if errors/warnings found, otherwise success (0)
if [ "$has_error_or_warning" -eq 1 ]; then
  echo "Cppcheck detected errors or warnings in your changed files."
  exit 1
else
  echo "Cppcheck passed with no errors or warnings in changed files."
  exit 0
fi
