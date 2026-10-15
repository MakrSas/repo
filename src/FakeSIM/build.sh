#!/bin/zsh
# Theos не поддерживает пробелы в пути, поэтому собираем в копии без пробелов.
# Использование: ./build.sh [папка-проекта] [install]
set -e
export THEOS=${THEOS:-$HOME/theos}
SRC="$(cd "$(dirname "$0")/${1:-.}" && pwd)"
BUILD="$HOME/.fakesim-build/$(basename "$SRC")"
mkdir -p "$BUILD"
rsync -a --delete --exclude .theos --exclude packages --exclude obj --exclude debug "$SRC/" "$BUILD/"
cd "$BUILD"
make clean package FINALPACKAGE=1
mkdir -p "$SRC/packages"
cp packages/*.deb "$SRC/packages/"
echo "Готово: $SRC/packages"
