#!/usr/bin/env perl
# Child runner for a typesetting job. Redirects the log, then replaces
# itself with vrain.pl so the WebUI can stream progress.
use strict;
use warnings;

@ARGV >= 3 or die "usage: run.pl logfile workdir command...\n";
my $log = shift @ARGV;
my $dir = shift @ARGV;

open my $lf, '>>:raw', $log or die "cannot open log: $!\n";
open STDOUT, '>&', $lf or die "stdout: $!\n";
open STDERR, '>&', $lf or die "stderr: $!\n";
select STDOUT;
$| = 1;
open STDIN, '<', ($^O eq 'MSWin32' ? 'NUL' : '/dev/null');
chdir $dir or die "chdir: $!\n";
exec { $ARGV[0] } @ARGV or die "exec: $!\n";
