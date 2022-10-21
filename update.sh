#!/bin/bash

TARGET_OS="$1"
TARGET_ARCH="$2"
TEMPDIR_BASE="$3"
DEST_PACKAGES_DIR="$4"
DEST_ARCHIVES_DIR="$5"
FAILED_PACKAGES="$6"
PACKAGES="satysfi satyrographos"
OPAM=opam
PYTHON=python
SEP="/"

# set -e

mkdir -p "$DEST_ARCHIVES_DIR" "$DEST_PACKAGES_DIR"

if [[ "$TARGET_OS" = "Windows" ]]; then
	if [[ "$TARGET_ARCH" = "X86" ]]; then
		TARGET_OS="win32"
	elif [[ "$TARGET_ARCH" = "X64" ]]; then
		TARGET_OS="win64"
	fi
	if where opam.cmd &>/dev/null ; then
		OPAM="$(where opam.cmd)"
	elif where opam.exe &>/dev/null ; then
		OPAM="$(where opam.exe)"
	fi
	SEP='\'
	PYTHON=python.exe
	DEST_ARCHIVES_DIR=$(echo "$DEST_ARCHIVES_DIR" | sed -e 's:/:\\:g')
	DEST_PACKAGES_DIR=$(echo "$DEST_PACKAGES_DIR" | sed -e 's:/:\\:g')
	FAILED_PACKAGES=$(echo "$FAILED_PACKAGES" | sed -e 's:/:\\:g')
elif [[ "$TARGET_OS" = "Linux" ]]; then
	TARGET_OS="linux"
elif [[ "$TARGET_OS" = "macOS" ]]; then
	TARGET_OS="macos"
	alias sed='gsed'
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


if [[ -z "$TEMPDIR_BASE" ]]; then
	TEMPDIR_BASE="${DEST_PACKAGES_DIR}$SEP..${SEP}temp"
fi
mkdir -p "$TEMPDIR_BASE"


eval $($OPAM env)
$OPAM list --columns=package --installable --color=never --or -A -V $PACKAGES | sed -e '/^#/d' | \
while read PKGNAME; do
	PKGBASE="${PKGNAME%%.*}"
	TEMPDIR="$TEMPDIR_BASE$SEP$PKGNAME"
	DEST_PKGNAME="$PKGNAME+bin_${TARGET_ARCH}_${TARGET_OS}"
	ARCHIVE_NAME="${DEST_PKGNAME}.tar.gz"
	ARCHIVE_PATH="$DEST_ARCHIVES_DIR$SEP$ARCHIVE_NAME"
	DEST_OPAM_PATH="$DEST_PACKAGES_DIR$SEP$PKGBASE$SEP$DEST_PKGNAME${SEP}opam"
	if [[ ! -f "$ARCHIVE_PATH" ]]; then
		if grep -q "^$ARCHIVE_NAME\$" blacklist ; then
			echo "# Skipping blacklist package $ARCHIVE_NAME" 1>&2
			continue
		fi
		echo "# Generating archive $ARCHIVE_NAME" 1>&2
		rm -rf "$TEMPDIR" && mkdir -p "$TEMPDIR"
		echo "## Installing $PKGNAME" 1>&2
		if $OPAM install "$PKGNAME" -v -y ; then
			echo "## Copying files..." 1>&2
			$OPAM show --list-files "$PKGNAME" | sed -e '/^\s*$/d' | \
			while read SRC; do
				# relative path from switch root
				REL="$(echo "$SRC" | sed -e 's:^.*[/\\]_opam[/\\]::' -e 's:^.*[/\\].opam[/\\][^/\\]\+[/\\]::')"
				echo "### Copying $SRC to $TEMPDIR$SEP$REL" 1>&2
				if [[ -d "$SRC" ]]; then
					mkdir -p "$TEMPDIR$SEP$REL"
				else
					mkdir -p "$TEMPDIR$SEP${REL%/*}"
					cp -R "$SRC" "$TEMPDIR$SEP$REL"
				fi
				[ -e "$TEMPDIR$SEP$REL" ]
				echo "$REL"
			done > "$TEMPDIR${SEP}files"
			echo "## Removing package $PKGNAME" 1>&2
			$OPAM remove -a -y "$PKGNAME" || true
			echo "## Writing $PKGBASE.install..." 1>&2
			echo "bin: [" > "$TEMPDIR$SEP$PKGBASE.install"
			cat "$TEMPDIR${SEP}files" | \
			while read REL; do
				[[ "${REL%%/*}" = "bin" ]] && echo "  \"$REL\""
			done >> "$TEMPDIR$SEP$PKGBASE.install"
			echo "]" >> "$TEMPDIR$SEP$PKGBASE.install"
			echo "doc: [" >> "$TEMPDIR$SEP$PKGBASE.install"
			cat "$TEMPDIR${SEP}files" | \
			while read REL; do
				[[ "${REL%%/*}" = "doc" ]] && echo "  \"$REL\""
			done >> "$TEMPDIR$SEP$PKGBASE.install"
			echo "]" >> "$TEMPDIR$SEP$PKGBASE.install"
			rm "$TEMPDIR${SEP}files"
			echo "## Packing files..." 1>&2
			(cd "$TEMPDIR" && tar czvf "$ARCHIVE_PATH" . --force-local )
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
		URL=$(echo -e "from urllib.parse import quote\nprint(quote(\"$DEST_PKGNAME\"))" | $PYTHON)
		mkdir -p "$DEST_PACKAGES_DIR$SEP$PKGBASE$SEP$DEST_PKGNAME"
		echo "# Generating OPAM file for $DEST_OPAM_PATH" 1>&2
		$OPAM show --raw --no-lint "$PKGNAME" | sed -e '/^name:/d' -e '/^version:/d' | \
		sed -ze 's/url\s*{[^}]*}//' | sed -ze 's/depends:\s*\[[^]]*\]/depends: []/' | \
		sed -ze 's/build:\s*\[[^]]*\(\[[^]]*\][^]]*\)*\]//' | \
		sed -ze 's/install:\s*\[[^]]*\(\[[^]]*\][^]]*\)*\]//' | \
		sed -ze 's/remove:\s*\[[^]]*\(\[[^]]*\][^]]*\)*\]//' > "$DEST_OPAM_PATH"
		echo "url {" >> "$DEST_OPAM_PATH"
		echo "  archive: \"https://github.com/yasuo-ozu/satyrographos-repo-bin/raw/main/store/archives/${URL}.tar.gz\"" >> "$DEST_OPAM_PATH"
		echo "  checksum: \"$MD5SUM\"" >> "$DEST_OPAM_PATH"
		echo "}" >> "$DEST_OPAM_PATH"
		echo "available: [ os = \"$TARGET_OS\" & arch = \"$TARGET_ARCH\" ]" >> "$DEST_OPAM_PATH"
	else
		echo "# Skipping opam $PKGNAME" 1>&2
	fi
done
