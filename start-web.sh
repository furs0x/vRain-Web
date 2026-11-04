#!/bin/sh
# Development launcher. Portable packages ship their own start script.
cd "$(dirname "$0")" || exit 1
if [ -x runtime/perl/bin/perl ]; then
  exec runtime/perl/bin/perl web/server.pl "$@"
fi
exec perl web/server.pl "$@"
