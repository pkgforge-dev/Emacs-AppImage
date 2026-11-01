#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q emacs | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/128x128/apps/emacs.png
export DESKTOP=/usr/share/applications/emacs.desktop

# Deploy dependencies
quick-sharun \
   /usr/bin/emacs* \
   /usr/lib/emacs \
   /usr/share/emacs

# Additional changes can be done in between here

# Emacs only loads a bundled .eln in place of its .elc when the .eln is at
# least as new as the .elc (maybe_swap_for_eln1 in src/lread.c), and the
# deployment gives the two trees copy timestamps, so a .eln can end up older
# than its .elc and be silently skipped.  Refresh them after the deployment.
find ./AppDir -name '*.eln' -exec touch {} +

# Runtime native compilation needs a C toolchain and a matching libgccjit on
# the host, so ship a site-start.el that turns it off; users can enable it.
mkdir -p ./AppDir/share/emacs/site-lisp
cat << 'EOF' > ./AppDir/share/emacs/site-lisp/site-start.el
;;; site-start.el --- provided by the Emacs AppImage  -*- lexical-binding: t; -*-

;; Lisp that ships without a bundled .eln would be native compiled at
;; runtime, which needs a C compiler this AppImage cannot rely on.
;; Set these back to t in your init file if your system has one.

(setq native-comp-jit-compilation nil
      native-comp-enable-subr-trampolines nil)

;;; site-start.el ends here
EOF

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
