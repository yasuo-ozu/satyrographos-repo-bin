#!/bin/bash

DEST_REPO_DIR="$1"
DEST_STORE_DIR="$2"
DEST_ARCHIVES_DIR="$DEST_STORE_DIR/archives"
LOCAL_OPAM_BIN_STORE="$HOME/.opam/plugins/opam-bin/store"

rm -rf "$LOCAL_OPAM_BIN_STORE/repo" "$LOCAL_OPAM_BIN_STORE/archives"
mkdir -p "$DEST_REPO_DIR" "$DEST_ARCHIVES_DIR"
ln -snf "$DEST_REPO_DIR" "$LOCAL_OPAM_BIN_STORE/repo"
ln -snf "$DEST_ARCHIVES_DIR" "$LOCAL_OPAM_BIN_STORE/archives"

PACKAGES="satysfi satyrographos"

mkdir -p "$DEST_REPO_DIR/build-log"

eval $(opam env) && opam list --columns=package --installable --color=never --or -A -V $PACKAGES | sed -e '/^#/d' | \
while read PKGNAME; do
	echo "Installing $PKGNAME"
	eval $(opam env) && opam install "$PKGNAME" -v -y && opam remove -a -y "$PKGNAME" || true
done
