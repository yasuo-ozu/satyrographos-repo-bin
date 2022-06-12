#!/bin/bash

SRC_DIR="$1"
DEST_REPO_DIR="$2"
DEST_STORE_DIR="$3"
DEST_ARCHIVES_DIR="$DEST_STORE_DIR/archives"
LOCAL_OPAM_BIN_STORE="$HOME/.opam/plugins/opam-bin/store"

rm -rf "$LOCAL_OPAM_BIN_STORE/repo" "$LOCAL_OPAM_BIN_STORE/archives"
mkdir -p "$DEST_REPO_DIR" "$DEST_ARCHIVES_DIR"
ln -snf "$DEST_REPO_DIR" "$LOCAL_OPAM_BIN_STORE/repo"
ln -snf "$DEST_ARCHIVES_DIR" "$LOCAL_OPAM_BIN_STORE/archives"

PACKAGES=(satysfi satyrographos)

eval $(opam env) && opam-bin config --base-url "https://raw.githubusercontent.com/yasuo-ozu/satyrographos-repo-bin/main"

for PACKAGE in "${PACKAGES[@]}"; do
	find "$SRC_DIR/packages/$PACKAGE" -maxdepth 1 -mindepth 1 -type d | xargs -I{} sh -c "opam install {} -v -y && opam remove -a -y {} || true"
done
