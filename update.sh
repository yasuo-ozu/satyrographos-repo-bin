#!/bin/bash

TARGET_OS="$1"
TARGET_ARCH="$2"
DEST_LOG_DIR="$3"
DEST_PACKAGES_DIR="$4"
DEST_ARCHIVES_DIR="$5"
PACKAGES="satysfi satyrographos"

set -e

mkdir -p "$DEST_ARCHIVES_DIR" "$DEST_PACKAGES_DIR" "$DEST_LOG_DIR"

if [[ "$TARGET_OS" = "Windows" && "$TARGET_ARCH" = "X86" ]]; then
	TARGET_OS="win32"
elif [[ "$TARGET_OS" = "Windows" && "$TARGET_ARCH" = "X64" ]]; then
	TARGET_OS="win64"
elif [[ "TARGET_OS" = "Linux" ]]; then
	TARGET_OS="linux"
elif [[ "TARGET_OS" = "macOS" ]]; then
	TARGET_OS="macos"
fi

if [[ "$TARGET_ARCH" = "X86" ]]; then
	TARGET_ARCH="x86_32"
elif [[ "$TARGET_ARCH" = "X64" ]]; then
	TARGET_ARCH="x86_64"
elif [[ "$TARGET_ARCH" = "ARM" ]]; then
	TARGET_ARCH="arm32"
elif [[ "$TARGET_ARCH" = "ARM64" ]]; then
	TARGET_ARCH="arm64"
fi

eval $(opam env) && opam list --columns=package --installable --color=never --or -A -V $PACKAGES | sed -e '/^#/d' | tac | \
while read PKGNAME; do
	PKGBASE="${PKGNAME%%.*}"
	TEMPDIR="$DEST_ARCHIVES_DIR/$PKGNAME"
	if [[ ! -f "$DEST_ARCHIVES_DIR/$PKGNAME+bin.tar.gz" ]]; then
		echo "Installing $PKGNAME ($PKGBASE)"
		(
			rm -rf "$TEMPDIR" && mkdir -p "$TEMPDIR"
			eval $(opam env) && opam install "$PKGNAME" -v -y
			echo "Copying files..."
			eval $(opam env) && opam show --list-files "$PKGNAME" | sed -e '/^\s*$/d' | \
			while read SRC; do
				# relative path from switch root
				REL="$(echo "$SRC" | sed -e 's:^.*/_opam/::' -e 's:^.*/.opam/[^/]\+/::')"
				echo "Copying $SRC to $TEMPDIR/$REL" 1>&2
				if [[ -d "$SRC" ]]; then
					mkdir -p "$TEMPDIR/$REL"
				else
					mkdir -p "$TEMPDIR/${REL%/*}"
					cp -r "$SRC" "$TEMPDIR/$REL"
				fi
				echo "$REL"
			done > "$TEMPDIR/files"
			echo "Removing package..."
			eval $(opam env) && opam remove -a -y "$PKGNAME" || true
			echo "Writing install file..."
			echo "bin: [" > "$TEMPDIR/$PKGBASE.install"
			cat "$TEMPDIR/files" | while read REL; do
				[[ "${REL%%/*}" = "bin" ]] && echo "  \"$REL\""
				done >> "$TEMPDIR/$PKGBASE.install"
				echo "]" >> "$TEMPDIR/$PKGBASE.install"
				echo "doc: [" >> "$TEMPDIR/$PKGBASE.install"
				cat "$TEMPDIR/files" | while read REL; do
				[[ "${REL%%/*}" = "doc" ]] && echo "  \"$REL\""
			done >> "$TEMPDIR/$PKGBASE.install"
			echo "]" >> "$TEMPDIR/$PKGBASE.install"
			rm "$TEMPDIR/files"
			echo "Packing files..."
			tar czvf "$DEST_ARCHIVES_DIR/$PKGNAME+bin.tar.gz" "$TEMPDIR"
			# rm -rf "$TEMPDIR"
		) || (echo "Failed to generate archive for $PKGNAME"; opam remove -a -y "$PKGNAME"; rm -f "$DEST_ARCHIVES_DIR/$PKGNAME+bin.tar.gz")
	else
		echo "Skipping store $PKGNAME ($PKGBASE)"
	fi
	if [[ -f "$DEST_ARCHIVES_DIR/$PKGNAME+bin.tar.gz" && ! -f "$DEST_PACKAGES_DIR/$PKGBASE/$PKGNAME+bin/opam" ]]; then
		MD5SUM=$(md5sum "$DEST_ARCHIVES_DIR/$PKGNAME+bin.tar.gz")
		URL=$(echo -e "from urllib.parse import quote\nprint(quote(\"https://github.com/yasuo-ozu/satyrographos-repo-bin/raw/main/store/archives/$PKGNAME+bin.tar.gz\"))" | python)
		mkdir -p "$DEST_PACKAGES_DIR/$PKGBASE/$PKGNAME+bin"
		eval $(opam env) && opam show --raw --no-lint "$PKGNAME" | sed -e '/^name:/d' -e '/^version:/d' | sed -ze 's/url\s*{[^}]*}//' | sed -ze 's/depends:\s*\[[^]]*\]/depends: []/' > "$DEST_PACKAGES_DIR/$PKGBASE/$PKGNAME+bin/opam"
		echo "url {" >> "$DEST_PACKAGES_DIR/$PKGBASE/$PKGNAME+bin/opam"
		echo "  archive: \"$URL\"" >> "$DEST_PACKAGES_DIR/$PKGBASE/$PKGNAME+bin/opam"
		echo "  checksum: \"$MD5SUM\"" >> "$DEST_PACKAGES_DIR/$PKGBASE/$PKGNAME+bin/opam"
		echo "}" >> "$DEST_PACKAGES_DIR/$PKGBASE/$PKGNAME+bin/opam"
	else
		echo "Skipping opam $PKGNAME ($PKGBASE)"
	fi
done
