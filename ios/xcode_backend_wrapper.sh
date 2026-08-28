#!/bin/sh
# Strips iCloud/File Provider extended attributes while Flutter builds.
# Required when the project lives on Desktop (macOS adds metadata that breaks codesign).

strip_xattrs() {
  if [ -d "${SRCROOT}/../build/ios" ]; then
    xattr -cr "${SRCROOT}/../build/ios" 2>/dev/null || true
  fi
  if [ -n "${BUILT_PRODUCTS_DIR}" ] && [ -d "${BUILT_PRODUCTS_DIR}" ]; then
    xattr -cr "${BUILT_PRODUCTS_DIR}" 2>/dev/null || true
  fi
}

strip_xattrs

(
  while true; do
    strip_xattrs
    sleep 0.2
  done
) &
STRIP_PID=$!

/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" "$@"
EXIT_CODE=$?

kill "$STRIP_PID" 2>/dev/null || true
wait "$STRIP_PID" 2>/dev/null || true
strip_xattrs

exit "$EXIT_CODE"
