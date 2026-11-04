#!/usr/bin/env bash
# Build a zero-install vRain Web package for the current OS.
# Linux and macOS use skaji relocatable-perl. Windows uses Strawberry Perl
# portable. Font::FreeType is linked against a static FreeType so the package
# does not need a system FreeType, Perl, or ImageMagick install.
set -eu
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

REL_PERL_VERSION=5.42.2.0
STRAWBERRY_VERSION=5.40.5.1
STRAWBERRY_TAG=SP_54051_64bit
FT_VERSION=2.13.3
VERSION=${VRAIN_VERSION:-dev}
VERSION=$(printf '%s' "$VERSION" | tr -c 'A-Za-z0-9._-' '-')

log() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s\n' "$1"
  fi
}

# Git Bash tar is GNU tar and will not unpack a zip. Windows ships bsdtar.
win_tar() {
  MSYS_NO_PATHCONV=1 /c/Windows/System32/tar.exe "$@"
}

download() {
  url=$1
  dest=$2
  if [ -f "$dest" ]; then
    log "cache $(basename "$dest")"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  log "download $url"
  curl -fL --retry 5 --retry-delay 2 -o "$dest.partial" "$url" || return 1
  mv "$dest.partial" "$dest"
}

detect_platform() {
  if [ -n "${PLATFORM:-}" ]; then
    printf '%s\n' "$PLATFORM"
    return 0
  fi
  os=$(uname -s)
  arch=$(uname -m)
  case "$os" in
    Linux)
      case "$arch" in
        x86_64|amd64) printf '%s\n' linux-x64 ;;
        aarch64|arm64) printf '%s\n' linux-arm64 ;;
        *) die "unsupported Linux architecture: $arch" ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        arm64) printf '%s\n' darwin-arm64 ;;
        x86_64) printf '%s\n' darwin-x64 ;;
        *) die "unsupported macOS architecture: $arch" ;;
      esac
      ;;
    MINGW*|MSYS*|CYGWIN*)
      printf '%s\n' windows-x64
      ;;
    *)
      die "unsupported operating system: $os"
      ;;
  esac
}

PLATFORM=$(detect_platform)
log "platform $PLATFORM version $VERSION"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v cmake >/dev/null 2>&1 || die "cmake is required"
command -v tar >/dev/null 2>&1 || die "tar is required"

CACHE="$ROOT/packaging/cache"
DEPS="$ROOT/build/deps"
STAGE="$ROOT/build/stage/vRain-Web-$PLATFORM"
mkdir -p "$CACHE" "$DEPS"
rm -rf "$STAGE"
mkdir -p "$STAGE/runtime"

perl_asset() {
  case "$PLATFORM" in
    linux-x64) printf '%s\n' perl-linux-amd64.tar.gz ;;
    linux-arm64) printf '%s\n' perl-linux-arm64.tar.gz ;;
    darwin-arm64) printf '%s\n' perl-darwin-arm64.tar.gz ;;
    darwin-x64) printf '%s\n' perl-darwin-amd64.tar.gz ;;
    *) die "no relocatable perl asset for $PLATFORM" ;;
  esac
}

install_relocatable_perl() {
  asset=$(perl_asset)
  download \
    "https://github.com/skaji/relocatable-perl/releases/download/${REL_PERL_VERSION}/${asset}" \
    "$CACHE/$asset"
  work="$ROOT/build/perl-extract"
  rm -rf "$work"
  mkdir -p "$work"
  tar -xzf "$CACHE/$asset" -C "$work"
  found=$(find "$work" -type f -path '*/bin/perl' | head -1)
  [ -n "$found" ] || die "perl binary not found in $asset"
  prefix=$(CDPATH= cd -- "$(dirname "$found")/.." && pwd)
  rm -rf "$STAGE/runtime/perl"
  mv "$prefix" "$STAGE/runtime/perl"
  rm -rf "$work"
  PERL="$STAGE/runtime/perl/bin/perl"
  [ -x "$PERL" ] || die "missing $PERL"
}

install_strawberry() {
  zipname="strawberry-perl-${STRAWBERRY_VERSION}-64bit-portable.zip"
  url="https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/${STRAWBERRY_TAG}/${zipname}"
  if ! download "$url" "$CACHE/$zipname"; then
    zipname="strawberry-perl-5.40.4.1-64bit-portable.zip"
    url="https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54041_64bit/${zipname}"
    download "$url" "$CACHE/$zipname"
  fi
  work="$ROOT/build/perl-extract"
  rm -rf "$work"
  mkdir -p "$work"
  win_tar -xf "$(native_path "$CACHE/$zipname")" -C "$(native_path "$work")"
  found=$(find "$work" -type f -name perl.exe | head -1)
  [ -n "$found" ] || die "perl.exe not found in Strawberry archive"
  src=$(dirname "$(dirname "$(dirname "$found")")")
  rm -rf "$STAGE/runtime/strawberry"
  mkdir -p "$STAGE/runtime/strawberry"
  mv "$src/perl" "$STAGE/runtime/strawberry/perl"
  if [ -d "$src/c" ]; then
    mv "$src/c" "$STAGE/runtime/strawberry/c"
  fi
  rm -rf "$work"
  PERL="$STAGE/runtime/strawberry/perl/bin/perl.exe"
  [ -f "$PERL" ] || die "missing $PERL"
  export PATH="$STAGE/runtime/strawberry/perl/bin:$STAGE/runtime/strawberry/c/bin:$PATH"
}

if [ "$PLATFORM" = "windows-x64" ]; then
  log "install Strawberry Perl"
  install_strawberry
else
  log "install relocatable Perl $REL_PERL_VERSION"
  install_relocatable_perl
fi
export PATH="$(dirname "$PERL"):$PATH"
"$PERL" -v

build_freetype() {
  tarball="$CACHE/freetype-${FT_VERSION}.tar.gz"
  if [ ! -f "$tarball" ]; then
    if ! download "https://download.savannah.gnu.org/releases/freetype/freetype-${FT_VERSION}.tar.gz" "$tarball"; then
      rm -f "$tarball.partial"
      ft_tag=$(printf '%s' "$FT_VERSION" | tr '.' '-')
      download "https://github.com/freetype/freetype/archive/refs/tags/VER-${ft_tag}.tar.gz" "$tarball"
    fi
  fi
  src="$ROOT/build/freetype-src"
  rm -rf "$src"
  mkdir -p "$src"
  tar -xzf "$tarball" -C "$src"
  cmake_src=$(find "$src" -name CMakeLists.txt -print | head -1)
  [ -n "$cmake_src" ] || die "FreeType sources have no CMakeLists.txt"
  cmake_src=$(dirname "$cmake_src")
  prefix="$DEPS/freetype"
  rm -rf "$prefix" "$src/build"
  prefix_native=$(native_path "$prefix")
  cmake_args="-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_INSTALL_PREFIX=$prefix_native -DFT_DISABLE_ZLIB=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON"
  if [ "$PLATFORM" = "windows-x64" ]; then
    gcc=$(native_path "$STAGE/runtime/strawberry/c/bin/gcc.exe")
    if [ -f "$STAGE/runtime/strawberry/c/bin/mingw32-make.exe" ]; then
      makebin=$(native_path "$STAGE/runtime/strawberry/c/bin/mingw32-make.exe")
    else
      makebin=$(native_path "$STAGE/runtime/strawberry/c/bin/gmake.exe")
    fi
    # shellcheck disable=SC2086
    cmake -S "$(native_path "$cmake_src")" -B "$(native_path "$src/build")" -G "MinGW Makefiles" \
      -DCMAKE_C_COMPILER="$gcc" -DCMAKE_MAKE_PROGRAM="$makebin" $cmake_args
    cmake --build "$(native_path "$src/build")" --parallel
    cmake --install "$(native_path "$src/build")"
  else
    if [ "$(uname -s)" = "Darwin" ]; then
      export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
    fi
    # shellcheck disable=SC2086
    cmake -S "$cmake_src" -B "$src/build" -DCMAKE_C_FLAGS="-fPIC" $cmake_args
    cmake --build "$src/build" --parallel
    cmake --install "$src/build"
  fi
  FT_LIB=$(find "$prefix" \( -name 'libfreetype.a' -o -name 'libfreetype.dll.a' \) | head -1)
  [ -n "$FT_LIB" ] || die "static libfreetype was not installed"
  case "$FT_LIB" in
    *.dll.a) die "FreeType built an import library; expected a static libfreetype.a" ;;
  esac
  FT_LIBDIR=$(dirname "$FT_LIB")
  FT_HEADER=$(find "$prefix" -name ft2build.h | head -1)
  [ -n "$FT_HEADER" ] || die "ft2build.h missing"
  FT_INCDIR=$(dirname "$FT_HEADER")
  mkdir -p "$prefix/bin"
  inc_native=$(native_path "$FT_INCDIR")
  lib_native=$(native_path "$FT_LIBDIR")
  case "$PLATFORM" in
    # Devel::CheckLib only accepts -l/-L/-R. A lone libfreetype.a in this
    # directory is what the linker picks up, so the extension stays static.
    windows-x64) libs="-L$lib_native -lfreetype" ;;
    *) libs="-L$lib_native -lfreetype -lm" ;;
  esac
  if [ "$PLATFORM" = "windows-x64" ]; then
    cat > "$prefix/bin/freetype-config.pl" << EOF
use strict;
binmode STDOUT;
my \$mode = \$ARGV[0] || '';
if (\$mode eq '--cflags') { print "-I$inc_native\\n"; }
elsif (\$mode eq '--libs') { print "$libs\\n"; }
else { print "$FT_VERSION\\n"; }
EOF
    perl_native=$(native_path "$PERL")
    pl_native=$(native_path "$prefix/bin/freetype-config.pl")
    cat > "$prefix/bin/freetype-config.bat" << EOF
@echo off
"$perl_native" "$pl_native" %*
EOF
  else
    cat > "$prefix/bin/freetype-config" << EOF
#!/bin/sh
case "\$1" in
  --cflags) printf '%s\n' "-I$inc_native" ;;
  --libs) printf '%s\n' "$libs" ;;
  *) printf '%s\n' "$FT_VERSION" ;;
esac
EOF
    chmod +x "$prefix/bin/freetype-config"
  fi
  export PATH="$prefix/bin:$PATH"
}

log "build static FreeType $FT_VERSION"
build_freetype
hash -r 2>/dev/null || true
if [ "$PLATFORM" = "windows-x64" ]; then
  FTCFG="freetype-config.bat"
else
  FTCFG="freetype-config"
fi
log "freetype-config --libs => $($FTCFG --libs)"
log "freetype-config --cflags => $($FTCFG --cflags)"

log "install pure-Perl modules"
# Copy these straight into sitelib. cpanm on Windows can report Font::TTF as
# installed and then still refuse to load it for PDF::Builder.
# Strawberry's Config still says C:/strawberry after the zip is unpacked.
# @INC is rewritten to the real directory, so install where perl will look.
sitelib=$("$PERL" -MConfig -e 'my $arch=$Config{archname}; for my $p (@INC) { next unless $p =~ /site/; next if $arch && $p =~ /\Q$arch\E/; $p =~ s{\\}{/}g; print $p; exit } die "no sitelib\n"')
[ -n "$sitelib" ] || die "perl sitelib is empty"
case "$sitelib" in
  *[Cc]:/strawberry/*) die "sitelib is still the Strawberry build prefix: $sitelib" ;;
esac
mkdir -p "$sitelib"
install_pure() {
  url=$1
  tarball="$CACHE/$(basename "$url")"
  download "$url" "$tarball"
  dest="$ROOT/build/pure/$(basename "$tarball" .tar.gz)"
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xzf "$tarball" -C "$dest"
  top=$(find "$dest" -mindepth 1 -maxdepth 1 -type d -print | head -1)
  [ -n "$top" ] || die "archive $(basename "$tarball") did not extract"
  if [ -d "$top/lib" ]; then
    cp -a "$top/lib/." "$sitelib/"
  elif [ -f "$top/String.pm" ]; then
    mkdir -p "$sitelib/IO"
    cp -a "$top/String.pm" "$sitelib/IO/String.pm"
  else
    die "no installable modules in $(basename "$tarball")"
  fi
  log "copied $(basename "$tarball") into $sitelib"
}
install_pure "https://cpan.metacpan.org/authors/id/G/GA/GAAS/IO-String-1.08.tar.gz"
install_pure "https://cpan.metacpan.org/authors/id/B/BH/BHALLISSY/Font-TTF-1.06.tar.gz"
install_pure "https://cpan.metacpan.org/authors/id/P/PM/PMPERRY/PDF-Builder-3.028.tar.gz"
install_pure "https://cpan.metacpan.org/authors/id/M/MA/MATTN/Devel-CheckLib-1.16.tar.gz"
install_pure "https://cpan.metacpan.org/authors/id/P/PL/PLICEASE/File-Which-1.27.tar.gz"
"$PERL" -MIO::String -MFont::TTF -MPDF::Builder -MDevel::CheckLib -MFile::Which -e 'print "PDF::Builder ", PDF::Builder->VERSION, "\n"'

export PERL_MM_USE_DEFAULT=1
export PERL_MM_NONINTERACTIVE=1
export PERL_CANARY_STABILITY_DISABLE=1

# Link the static archive by path. macOS ld otherwise prefers a Homebrew
# libfreetype.dylib, and Devel::CheckLib rejects -Wl flags in --libs.
log "build Font::FreeType against static FreeType"
ft_src="$ROOT/build/Font-FreeType"
rm -rf "$ft_src"
mkdir -p "$ft_src"
download "https://cpan.metacpan.org/authors/id/D/DM/DMOL/Font-FreeType-0.18.tar.gz" "$CACHE/Font-FreeType-0.18.tar.gz"
tar -xzf "$CACHE/Font-FreeType-0.18.tar.gz" -C "$ft_src"
ft_dir=$(find "$ft_src" -name Makefile.PL -print | head -1)
[ -n "$ft_dir" ] || die "Font::FreeType sources missing"
ft_dir=$(dirname "$ft_dir")
(
  cd "$ft_dir"
  if [ "$PLATFORM" = "windows-x64" ]; then
    # The runner may already have C:/strawberry. MakeMaker reads that tree,
    # then asks for headers this portable build does not ship.
    # A quoted "cmd /c" line parses /runtime as the /r switch. A batch
    # file keeps the backslashes as path characters.
    target=$(native_path "$STAGE/runtime/strawberry" | tr '/' '\\')
    bat="$ROOT/build/link-strawberry.bat"
    {
      printf '%s\r\n' '@echo on'
      printf '%s\r\n' 'if exist C:\strawberry.host-saved rmdir /S /Q C:\strawberry.host-saved'
      printf '%s\r\n' 'if exist C:\strawberry move C:\strawberry C:\strawberry.host-saved'
      printf '%s\r\n' 'if errorlevel 1 exit /b 1'
      printf 'mklink /J C:\strawberry "%s"\r\n' "$target"
      printf '%s\r\n' 'if errorlevel 1 exit /b 1'
      printf '%s\r\n' 'echo JUNCTION_OK'
    } > "$bat"
    log "junction C:/strawberry to $target"
    sed 's/\r$//' "$bat"
    # Git Bash runs a .bat itself. cmd /c would treat /runtime in the
    # argument list as the /r switch, and MSYS_NO_PATHCONV leaves //c literal.
    "$bat"
    if [ ! -f /c/strawberry/perl/lib/CORE/libperl540.a ]; then
      ls -l /c/strawberry /c/strawberry/perl/lib/CORE 2>&1 | head -40 >&2 || true
      die "libperl540.a is not visible at C:/strawberry"
    fi
  fi
  "$PERL" Makefile.PL
  ft_a=$(native_path "$FT_LIB")
  prefix=""
  if [ "$PLATFORM" = "windows-x64" ]; then
    # Config.pm keeps the C:/strawberry prefix from the portable build.
    prefix=$(native_path "$STAGE/runtime/strawberry")
  fi
  # gmake does not treat a mix of / and \ as one path. Leave \"
  # alone: those escapes quote -DVERSION and must not become /".
  "$PERL" -i.bak -e '
    BEGIN {
      $lib = shift;
      $prefix = shift // "";
    }
    while (<>) {
      my $nl = chomp;
      my $cont = s/\\(\s*)\z//;
      s{-lfreetype\b}{$lib}g;
      s{C:[\\/]strawberry}{$prefix}g if $prefix ne "";
      s{\\(?!")}{/}g if $prefix ne "";
      $_ .= "\\" if $cont;
      $_ .= "\n" if $nl;
      print;
    }
  ' "$ft_a" "$prefix" Makefile
  grep -F "$ft_a" Makefile >/dev/null || die "Font::FreeType Makefile does not use the static library"
  if [ -n "$prefix" ]; then
    grep -F "$prefix" Makefile >/dev/null || die "Font::FreeType Makefile still points at C:/strawberry"
  fi
  makebin=$("$PERL" -MConfig -e 'print $Config{make}')
  "$makebin"
  "$makebin" install
)

log "verify font engine"
"$PERL" -MPDF::Builder -e 'print "PDF::Builder ", PDF::Builder->VERSION, "\n"'
# U+6C38 is ASCII in this script. A raw UTF-8 character in -e is not
# decoded by Windows perl, so the glyph lookup misses.
"$PERL" -MFont::FreeType -e 'my $ft = Font::FreeType->new; my $face = $ft->face($ARGV[0]); my $g = $face->glyph_from_char("\x{6C38}"); die "glyph missing\n" unless $g; print "Font::FreeType ok\n"' \
  "$ROOT/fonts/qiji-combo.ttf"

so=$(find "$STAGE/runtime" -type f \( -name 'FreeType.so' -o -name 'FreeType.bundle' -o -name 'FreeType.dll' -o -name 'FreeType.xs.dll' \) | head -1)
[ -n "$so" ] || die "Font::FreeType shared library was not built"
log "extension $so"
case "$PLATFORM" in
  linux-*)
    if ldd "$so" | grep -E 'libfreetype\.so'; then
      die "Font::FreeType is still linked to a shared libfreetype"
    fi
    ;;
  darwin-*)
    if otool -L "$so" | grep -E 'libfreetype[^/]*\.dylib'; then
      otool -L "$so" >&2
      die "Font::FreeType is still linked to a shared libfreetype"
    fi
    ;;
esac

if [ "$PLATFORM" = "windows-x64" ]; then
  log "collect Windows runtime DLLs"
  bindir="$STAGE/runtime/strawberry/perl/bin"
  cbin="$STAGE/runtime/strawberry/c/bin"
  if [ -n "$so" ] && command -v objdump >/dev/null 2>&1; then
    objdump -p "$so" | awk '/DLL Name/ {print $3}' | while read -r dll; do
      low=$(printf '%s' "$dll" | tr 'A-Z' 'a-z')
      case "$low" in
        kernel32.dll|kernelbase.dll|user32.dll|advapi32.dll|shell32.dll|ole32.dll|oleaut32.dll|ws2_32.dll|ntdll.dll|msvcrt.dll|ucrtbase.dll|comctl32.dll|gdi32.dll|imm32.dll|setupapi.dll|shlwapi.dll|crypt32.dll|bcrypt.dll|bcryptprimitives.dll|sechost.dll|rpcrt4.dll|combase.dll|winmm.dll|version.dll|psapi.dll|iphlpapi.dll|dnsapi.dll|mswsock.dll|nsi.dll|cryptbase.dll|wldap32.dll|normaliz.dll|cfgmgr32.dll|vcruntime*.dll)
          continue
          ;;
      esac
      if [ ! -f "$bindir/$dll" ] && [ -f "$cbin/$dll" ]; then
        cp "$cbin/$dll" "$bindir/$dll"
      fi
    done
  fi
  log "drop the Strawberry compiler tree"
  if [ -d "$cbin" ]; then
    find "$cbin" -type f ! -iname '*.dll' -delete || true
  fi
  rm -rf "$STAGE/runtime/strawberry/c/include" \
    "$STAGE/runtime/strawberry/c/lib" \
    "$STAGE/runtime/strawberry/c/share" \
    "$STAGE/runtime/strawberry/c/x86_64-w64-mingw32" || true
  PATH="$bindir:${PATH:-}" "$PERL" -MFont::FreeType -e 'print "Font::FreeType still loads\n"'
fi

log "remove Perl documentation"
find "$STAGE/runtime" -type d -name man -prune -exec rm -rf {} + 2>/dev/null || true
find "$STAGE/runtime" -type d -name pods -prune -exec rm -rf {} + 2>/dev/null || true
find "$STAGE/runtime" -type f -name '*.pod' -delete 2>/dev/null || true
rm -rf "$STAGE/runtime/perl/html" "$STAGE/runtime/strawberry/perl/html" 2>/dev/null || true

log "copy application files"
tar -C "$ROOT" -cf - vrain.pl vrain_mr.pl LICENSE web books books_mr canvas fonts db | tar -C "$STAGE" -xf -
find "$STAGE" -name '*.pdf' -type f -exec rm -f {} +
find "$STAGE" -name '*.tmp' -type f -exec rm -f {} +
find "$STAGE" -name '.DS_Store' -type f -exec rm -f {} +
rm -rf "$STAGE/web/jobs" "$STAGE/books/01/tmp" "$STAGE/books/01/export" "$STAGE/books/01/yin" \
  "$STAGE/books_mr/03" || true
find "$STAGE" -type d \( -name tmp -o -name export \) -exec rm -rf {} + 2>/dev/null || true

write_readme() {
  glibc_line=""
  if [ "${PLATFORM#linux-}" != "$PLATFORM" ] && command -v objdump >/dev/null 2>&1; then
    versions=$(objdump -T "$PERL" 2>/dev/null | grep -o 'GLIBC_[0-9][0-9.]*' || true)
    for bin in $(find "$STAGE/runtime" -type f -name '*.so'); do
      extra=$(objdump -T "$bin" 2>/dev/null | grep -o 'GLIBC_[0-9][0-9.]*' || true)
      versions="$versions
$extra"
    done
    glibc=$(printf '%s\n' "$versions" | sed 's/^GLIBC_//' | grep '^[0-9]' | sort -uV | tail -1 || true)
    if [ -n "${glibc:-}" ]; then
      printf '%s\n' "$glibc" > "$STAGE/runtime/GLIBC.txt"
      glibc_line="This Linux build needs glibc $glibc or newer (see runtime/GLIBC.txt)."
    fi
  fi
  cat > "$STAGE/README.txt" << EOF
vRain Web $VERSION ($PLATFORM)
兀雨可攜式套件。解壓後直接執行，不必另外安裝 Perl、字體或 ImageMagick。

Windows: 解壓 zip，雙擊 START.bat。若 SmartScreen 攔截，選「仍要執行」。
macOS:   tar -xzf 套件後，雙擊 start.command。若 Gatekeeper 攔截未簽名程式：
         xattr -dr com.apple.quarantine .
Linux:   tar -xzf 套件後，在終端機執行 ./start.sh
$glibc_line

瀏覽器會打開 http://127.0.0.1:8787/ （只聽本機）。
命令列仍可用：
  ./vrain -b sample -f 1 -t 1 -z 1
  ./perl vrain.pl -h
Windows 請改用 vrain.bat 與 perl.bat。

書葉背景圖已經附在套件裡。canvas/*.pl 重繪背景仍需要系統上的 ImageMagick，
網頁介面不依賴它。PDF 壓縮（-c）需要 Ghostscript，沒有時仍可產生 PDF。
EOF
}

write_unix_tools() {
  cat > "$STAGE/start.sh" << 'EOF'
#!/bin/sh
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT" || exit 1
if [ -x "$ROOT/runtime/perl/bin/perl" ]; then
  PERL="$ROOT/runtime/perl/bin/perl"
elif [ -x "$ROOT/runtime/strawberry/perl/bin/perl.exe" ]; then
  PERL="$ROOT/runtime/strawberry/perl/bin/perl.exe"
  PATH="$ROOT/runtime/strawberry/perl/bin:$ROOT/runtime/strawberry/c/bin:$PATH"
  export PATH
else
  echo "bundled perl not found" >&2
  exit 1
fi
if [ -d "$ROOT/runtime/lib" ]; then
  LD_LIBRARY_PATH="$ROOT/runtime/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  DYLD_LIBRARY_PATH="$ROOT/runtime/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
  export LD_LIBRARY_PATH DYLD_LIBRARY_PATH
fi
exec "$PERL" "$ROOT/web/server.pl" "$@"
EOF
  cp "$STAGE/start.sh" "$STAGE/start.command"
  cat > "$STAGE/vrain" << 'EOF'
#!/bin/sh
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT" || exit 1
if [ -x "$ROOT/runtime/perl/bin/perl" ]; then
  exec "$ROOT/runtime/perl/bin/perl" "$ROOT/vrain.pl" "$@"
fi
PATH="$ROOT/runtime/strawberry/perl/bin:$ROOT/runtime/strawberry/c/bin:$PATH"
export PATH
exec "$ROOT/runtime/strawberry/perl/bin/perl.exe" "$ROOT/vrain.pl" "$@"
EOF
  cat > "$STAGE/perl" << 'EOF'
#!/bin/sh
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT" || exit 1
if [ -x "$ROOT/runtime/perl/bin/perl" ]; then
  exec "$ROOT/runtime/perl/bin/perl" "$@"
fi
PATH="$ROOT/runtime/strawberry/perl/bin:$ROOT/runtime/strawberry/c/bin:$PATH"
export PATH
exec "$ROOT/runtime/strawberry/perl/bin/perl.exe" "$@"
EOF
  chmod +x "$STAGE/start.sh" "$STAGE/start.command" "$STAGE/vrain" "$STAGE/perl"
}

write_windows_tools() {
  cat > "$STAGE/START.bat" << 'EOF'
@echo off
setlocal
cd /d "%~dp0"
set "PATH=%~dp0runtime\strawberry\perl\bin;%~dp0runtime\strawberry\c\bin;%PATH%"
"%~dp0runtime\strawberry\perl\bin\perl.exe" "%~dp0web\server.pl" %*
if "%VRAIN_NO_PAUSE%"=="" pause
EOF
  cat > "$STAGE/vrain.bat" << 'EOF'
@echo off
setlocal
cd /d "%~dp0"
set "PATH=%~dp0runtime\strawberry\perl\bin;%~dp0runtime\strawberry\c\bin;%PATH%"
"%~dp0runtime\strawberry\perl\bin\perl.exe" "%~dp0vrain.pl" %*
EOF
  cat > "$STAGE/perl.bat" << 'EOF'
@echo off
setlocal
cd /d "%~dp0"
set "PATH=%~dp0runtime\strawberry\perl\bin;%~dp0runtime\strawberry\c\bin;%PATH%"
"%~dp0runtime\strawberry\perl\bin\perl.exe" %*
EOF
}

write_readme
write_unix_tools
if [ "$PLATFORM" = "windows-x64" ]; then
  write_windows_tools
fi

log "self-check inside the package"
( cd "$STAGE" && "$PERL" web/server.pl --self-check )

mkdir -p "$ROOT/dist"
rm -rf "$ROOT/dist/vRain-Web-$PLATFORM"
mv "$STAGE" "$ROOT/dist/vRain-Web-$PLATFORM"
archive_base="vRain-Web-${VERSION}-${PLATFORM}"
if [ "$PLATFORM" = "windows-x64" ]; then
  rm -f "$ROOT/dist/${archive_base}.zip"
  # System tar.exe segfaults while creating this zip. Python writes it.
  py=python
  command -v python >/dev/null 2>&1 || py=python3
  MSYS_NO_PATHCONV=1 "$py" - \
    "$(native_path "$ROOT/dist/${archive_base}.zip")" \
    "$(native_path "$ROOT/dist/vRain-Web-$PLATFORM")" << 'PY'
import os, sys, zipfile
dest, src = sys.argv[1], sys.argv[2]
parent = os.path.dirname(os.path.abspath(src))
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED, allowZip64=True) as zf:
    for dirpath, dirnames, filenames in os.walk(src):
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, parent).replace("\\", "/")
            zf.write(full, rel)
print("zipped", dest, flush=True)
PY
  log "wrote dist/${archive_base}.zip"
else
  rm -f "$ROOT/dist/${archive_base}.tar.gz"
  tar -C "$ROOT/dist" -czf "$ROOT/dist/${archive_base}.tar.gz" "vRain-Web-$PLATFORM"
  log "wrote dist/${archive_base}.tar.gz"
fi
