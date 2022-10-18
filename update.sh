#!/bin/bash

TARGET_OS="$1"
TARGET_ARCH="$2"
TEMPDIR_BASE="$3"
DEST_PACKAGES_DIR="$4"
DEST_ARCHIVES_DIR="$5"
FAILED_PACKAGES="$6"
PACKAGES="satysfi satyrographos"

if [[ -z "$TEMPDIR_BASE" ]]; then
	TEMPDIR_BASE="${DEST_PACKAGES_DIR}/../temp"
fi
mkdir -p "$TEMPDIR_BASE"

# set -e

mkdir -p "$DEST_ARCHIVES_DIR" "$DEST_PACKAGES_DIR"

if [[ "$TARGET_OS" = "Windows" && "$TARGET_ARCH" = "X86" ]]; then
	TARGET_OS="win32"
elif [[ "$TARGET_OS" = "Windows" && "$TARGET_ARCH" = "X64" ]]; then
	TARGET_OS="win64"
elif [[ "$TARGET_OS" = "Linux" ]]; then
	TARGET_OS="linux"
elif [[ "$TARGET_OS" = "macOS" ]]; then
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

eval $(opam env) && opam list --columns=package --installable --color=never --or -A -V $PACKAGES | sed -e '/^#/d' | \
while read PKGNAME; do
	PKGBASE="${PKGNAME%%.*}"
	TEMPDIR="$TEMPDIR_BASE/$PKGNAME"
	DEST_PKGNAME="$PKGNAME+bin"
	ARCHIVE_NAME="${DEST_PKGNAME}_${TARGET_ARCH}_${TARGET_OS}.tar.gz"
	ARCHIVE_PATH="$DEST_ARCHIVES_DIR/$ARCHIVE_NAME"
	DEST_OPAM_PATH="$DEST_PACKAGES_DIR/$PKGBASE/$DEST_PKGNAME/opam"
	if [[ ! -f "$ARCHIVE_PATH" ]]; then
		if grep -q "^$ARCHIVE_NAME\$" blacklist ; then
			echo "# Skipping blacklist package $ARCHIVE_NAME" 1>&2
			continue
		fi
		echo "# Generating archive $ARCHIVE_NAME" 1>&2
		rm -rf "$TEMPDIR" && mkdir -p "$TEMPDIR"
		echo "## Installing $PKGNAME" 1>&2
		if eval $(opam env) && opam install "$PKGNAME" -v -y ; then
			echo "## Copying files..." 1>&2
			eval $(opam env) && opam show --list-files "$PKGNAME" | sed -e '/^\s*$/d' | \
			while read SRC; do
				# relative path from switch root
				REL="$(echo "$SRC" | sed -e 's:^.*/_opam/::' -e 's:^.*/.opam/[^/]\+/::')"
				echo "### Copying $SRC to $TEMPDIR/$REL" 1>&2
				if [[ -d "$SRC" ]]; then
					mkdir -p "$TEMPDIR/$REL"
				else
					mkdir -p "$TEMPDIR/${REL%/*}"
					cp -r "$SRC" "$TEMPDIR/$REL"
				fi
				echo "$REL"
			done > "$TEMPDIR/files"
			echo "## Removing package $PKGNAME" 1>&2
			eval $(opam env) && opam remove -a -y "$PKGNAME" || true
			echo "## Writing $PKGBASE.install..." 1>&2
			echo "bin: [" > "$TEMPDIR/$PKGBASE.install"
			cat "$TEMPDIR/files" | \
			while read REL; do
				[[ "${REL%%/*}" = "bin" ]] && echo "  \"$REL\""
			done >> "$TEMPDIR/$PKGBASE.install"
			echo "]" >> "$TEMPDIR/$PKGBASE.install"
			echo "doc: [" >> "$TEMPDIR/$PKGBASE.install"
			cat "$TEMPDIR/files" | \
			while read REL; do
				[[ "${REL%%/*}" = "doc" ]] && echo "  \"$REL\""
			done >> "$TEMPDIR/$PKGBASE.install"
			echo "]" >> "$TEMPDIR/$PKGBASE.install"
			rm "$TEMPDIR/files"
			echo "## Packing files..." 1>&2
			tar czvf "$ARCHIVE_PATH" "$TEMPDIR"
			rm -rf "$TEMPDIR"
		else
			echo "## Failed to install $PKGNAME. Skipping archive generation for $ARCHIVE_NAME" 1>&2
		fi
	else
		echo "# Skipping archive generation for $ARCHIVE_NAME" 1>&2
		echo "$ARCHIVE_NAME" >> "$FAILED_PACKAGES"
	fi
	if [[ -f "$ARCHIVE_PATH" && ! -f "$DEST_OPAM_PATH" ]]; then
		MD5SUM=$(md5sum "$ARCHIVE_PATH" | sed -e 's/ .*$//')
		URL=$(echo -e "from urllib.parse import quote\nprint(quote(\"https://github.com/yasuo-ozu/satyrographos-repo-bin/raw/main/store/archives/$DEST_PKGNAME\"))" | python)
		mkdir -p "$DEST_PACKAGES_DIR/$PKGBASE/$DEST_PKGNAME"
		echo "# Generating OPAM file for $DEST_OPAM_PATH" 1>&2
		eval $(opam env) && opam show --raw --no-lint "$PKGNAME" | sed -e '/^name:/d' -e '/^version:/d' | sed -ze 's/url\s*{[^}]*}//' | sed -ze 's/depends:\s*\[[^]]*\]/depends: []/' > "$DEST_OPAM_PATH"
		echo "url {" >> "$DEST_OPAM_PATH"
		echo "  archive: \"${URL}_%{arch}%_%{os}%.tar.gz\"" >> "$DEST_OPAM_PATH"
		echo "  checksum: \"$MD5SUM\"" >> "$DEST_OPAM_PATH"
		echo "}" >> "$DEST_OPAM_PATH"
	else
		echo "# Skipping opam $PKGNAME" 1>&2
	fi
done
