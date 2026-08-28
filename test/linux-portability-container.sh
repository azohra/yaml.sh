#!/bin/sh
set -eu

portability_root=/tmp/ysh-portability
[ ! -e "$portability_root" ] || {
  printf '%s\n' "linux-portability: refusing — $portability_root already exists" >&2
  exit 1
}

mkdir -p \
  "$portability_root/busybox" \
  "$portability_root/gawk-posix" \
  "$portability_root/original-awk"

ln -s "$(command -v busybox)" "$portability_root/busybox/awk"
printf '%s\n' '#!/bin/sh' 'exec gawk --posix "$@"' > "$portability_root/gawk-posix/awk"
chmod 755 "$portability_root/gawk-posix/awk"
ln -s "$(command -v original-awk)" "$portability_root/original-awk/awk"

for awk_name in busybox gawk-posix original-awk; do
  printf '\nAWK: %s\n' "$awk_name"
  PATH="$portability_root/$awk_name:$PATH" make test docs-check
done

printf '\nShells: dash, bash --posix, busybox sh\n'
printf '%s\n' 'key: value' | dash ./ysh '.key'
printf '%s\n' 'key: value' | bash --posix ./ysh '.key'
printf '%s\n' 'key: value' | busybox sh ./ysh '.key'
