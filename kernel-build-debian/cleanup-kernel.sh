#!/usr/bin/env bash
# Safe kernel cleanup: keep current + KEEP previous kernels
set -euo pipefail

KEEP=${1:-1}     # number of previous kernels to keep (default 1). Current kernel always kept.
echo "Keeping current + $KEEP previous kernels."

current_ver="$(uname -r)"
echo "Current running kernel: $current_ver"

# collect installed linux-image packages (sorted by version)
mapfile -t images < <(dpkg-query -W -f='${Package} ${Version}\n' "linux-image-*" 2>/dev/null | sort -V -r | awk '{print $1}')

if [ ${#images[@]} -eq 0 ]; then
  echo "No linux-image packages found via dpkg-query."
  exit 0
fi

# Determine packages to keep
keep_list=()
count_prev=0
for pkg in "${images[@]}"; do
  # get package version string from dpkg
  ver="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo '')"
  if [[ "$ver" == *"$current_ver"* ]] || [[ "$pkg" == *"$current_ver"* ]]; then
    # always keep current
    keep_list+=("$pkg")
  elif [ $count_prev -lt "$KEEP" ]; then
    keep_list+=("$pkg")
    count_prev=$((count_prev+1))
  fi
done

echo "Keeping packages:"
printf '  %s\n' "${keep_list[@]}"

# Now build remove list (installed linux-image packages minus keep_list)
remove_list=()
for pkg in "${images[@]}"; do
  keep=false
  for k in "${keep_list[@]}"; do
    if [ "$pkg" = "$k" ]; then keep=true; break; fi
  done
  if ! $keep; then remove_list+=("$pkg"); fi
done

if [ ${#remove_list[@]} -eq 0 ]; then
  echo "Nothing to remove."
  exit 0
fi

echo "Removing these packages:"
printf '  %s\n' "${remove_list[@]}"

# Purge the packages
sudo apt purge -y "${remove_list[@]}"

# Cleanup orphaned packages
sudo apt autoremove -y
sudo update-grub || true

echo "Cleanup complete."
exit 0
