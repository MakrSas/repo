#!/bin/zsh
# Пересобирает индекс Sileo/APT-репозитория из debs/*.deb.
# Использование: положить .deb в debs/, запустить ./update.sh, закоммитить и запушить.
set -e
cd "$(dirname "$0")"

dpkg-scanpackages -m debs /dev/null > Packages 2>/dev/null
gzip -9 -k -f Packages
bzip2 -9 -k -f Packages
xz -9 -k -f Packages

hashes() {  # $1 = команда хеша, $2 = заголовок
	echo "$2:"
	for f in Packages Packages.gz Packages.bz2 Packages.xz; do
		printf " %s %s %s\n" "$(eval "$1" "$f" | awk '{print $1}')" "$(stat -f%z "$f")" "$f"
	done
}

{
	cat <<HDR
Origin: Makr Repo
Label: Makr Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm iphoneos-arm64
Components: main
Description: Tweaks by Makr
Date: $(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S UTC")
HDR
	hashes "md5 -r" MD5Sum
	hashes "shasum -a 1" SHA1
	hashes "shasum -a 256" SHA256
} > Release
echo "OK: $(grep -c '^Package:' Packages) пакет(ов)"
