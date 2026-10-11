#!/bin/sh
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# Install the Jennifer interpreter that CI runs against.
#
#   scripts/install-jennifer.sh 0.25.0     # a release: its checksummed .deb
#   scripts/install-jennifer.sh <commit>   # a main-branch commit, built with Go
#
# Building from a commit covers the stretch where cantrip needs library
# functions that no release carries yet. Either way the interpreter lands in
# PREFIX/bin and its modules in PREFIX/share/jennifer/modules; with the
# default PREFIX of /usr that is where a source build looks for them, exactly
# as the .deb lays them out. Set SUDO="" when running as root, or when PREFIX
# is somewhere you can write; then point JENNIFER_SYSMODDIR at the modules.

set -eu

ref="${1:?usage: install-jennifer.sh <release X.Y.Z | commit>}"
PREFIX="${PREFIX:-/usr}"
SUDO="${SUDO-sudo}"
repo="https://github.com/jennifer-language/jennifer"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

case "$ref" in
    [0-9]*.[0-9]*.[0-9]*)
        deb="jennifer_${ref}_amd64.deb"
        curl -fsSL -o "$work/$deb" "$repo/releases/download/$ref/$deb"
        curl -fsSL -o "$work/$deb.sha256" "$repo/releases/download/$ref/$deb.sha256"
        (cd "$work" && sha256sum -c "$deb.sha256")
        if [ "$PREFIX" = /usr ]; then
            $SUDO dpkg -i "$work/$deb"
        else
            mkdir -p "$work/root"
            if command -v dpkg-deb >/dev/null; then
                dpkg-deb -x "$work/$deb" "$work/root"
            else
                (cd "$work/root" && ar x "../$deb" && tar -xf data.tar.*)
            fi
            $SUDO mkdir -p "$PREFIX/bin" "$PREFIX/share/jennifer"
            $SUDO cp "$work/root/usr/bin/jennifer" "$PREFIX/bin/jennifer"
            $SUDO cp -r "$work/root/usr/share/jennifer/modules" "$PREFIX/share/jennifer/"
        fi
        ;;
    *)
        command -v go >/dev/null || {
            echo "install-jennifer: building commit $ref needs Go on PATH" >&2
            exit 1
        }
        git clone --quiet --filter=blob:none "$repo.git" "$work/src"
        git -C "$work/src" checkout --quiet "$ref"
        make -C "$work/src" build-go
        $SUDO mkdir -p "$PREFIX/bin" "$PREFIX/share/jennifer/modules"
        $SUDO install -m 0755 "$work/src/jennifer" "$PREFIX/bin/jennifer"
        $SUDO cp -r "$work/src/modules/." "$PREFIX/share/jennifer/modules/"
        ;;
esac

"$PREFIX/bin/jennifer" version
