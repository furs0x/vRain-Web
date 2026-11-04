#!/usr/bin/env perl
# vRain Web — local browser UI for the vrain.pl typesetter.
# Core Perl only. Bind address is always the loopback interface.
use strict;
use warnings;
use utf8;

use Config;
use Encode qw(decode encode FB_DEFAULT);
use Fcntl qw(F_GETFD F_SETFD FD_CLOEXEC);
use File::Basename qw(basename);
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);
use File::Spec;
use FindBin;
use IO::Select;
use IO::Socket::INET;
use JSON::PP;
use POSIX qw(WNOHANG strftime);

our $WEB_VERSION = '1.0.0';
our $ENGINE_VERSION = '1.5.1';

my $ROOT = $ENV{VRAIN_ROOT} || File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, '..'));
chdir $ROOT or die "chdir $ROOT: $!\n";

my $JSON = JSON::PP->new->utf8->canonical;
my $SERVER;
my $PORT = 8787;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';
$| = 1;
$SIG{PIPE} = 'IGNORE';

if (grep { $_ eq '--self-check' } @ARGV) {
    exit(self_check());
}

my $no_browser = $ENV{VRAIN_NO_BROWSER} ? 1 : 0;
my $arg_port;
for (my $i = 0; $i < @ARGV; $i++) {
    if ($ARGV[$i] eq '--port' && defined $ARGV[$i + 1]) {
        $arg_port = $ARGV[++$i];
    } elsif ($ARGV[$i] =~ /^--port=(\d+)\z/) {
        $arg_port = $1;
    } elsif ($ARGV[$i] eq '--no-browser') {
        $no_browser = 1;
    } elsif ($ARGV[$i] eq '--help' || $ARGV[$i] eq '-h') {
        print "perl web/server.pl [--port N] [--no-browser] [--self-check]\n";
        exit 0;
    }
}
$PORT = $arg_port if defined $arg_port && $arg_port =~ /^\d+$/;
$PORT = $ENV{VRAIN_PORT} if !defined $arg_port && ($ENV{VRAIN_PORT} || '') =~ /^\d+$/;

make_path(jobs_root());
($SERVER, $PORT) = listen_server($PORT);
cloexec($SERVER);

$SIG{INT} = $SIG{TERM} = sub {
    print "\n停止 / stopping\n";
    exit 0;
};

my $url = "http://127.0.0.1:$PORT/";
print "兀雨 vRain Web 已啟動 / ready\n";
print "VRAIN_READY $url\n";
print "按 Ctrl+C 停止 / Press Ctrl+C to stop\n";
open_browser($url) unless $no_browser;

my $select = IO::Select->new($SERVER);
while (1) {
    my @ready = $select->can_read(1);
    next unless @ready;
    my $client = $SERVER->accept();
    next unless $client;
    $client->autoflush(1);
    $client->timeout(120);
    binmode $client;
    cloexec($client);
    eval { handle_client($client) };
    if ($@) {
        my $err = "$@";
        $err =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
        $err =~ s/\s+\z//;
        my $code = 500;
        my $text = 'Error';
        if ($err =~ s/\A(\d{3})\s+//) {
            $code = $1;
            $text = status_text($code);
        }
        eval { send_json($client, $code, $text, { error => $err || 'error' }); };
        warn "request failed: $err\n" if $code >= 500;
    }
    close $client;
}

sub listen_server {
    my ($port) = @_;
    $port = 8787 unless $port && $port > 0 && $port < 65535;
    for my $p ($port .. $port + 20) {
        my $srv = IO::Socket::INET->new(
            LocalAddr => '127.0.0.1',
            LocalPort => $p,
            Listen    => 20,
            ReuseAddr => 1,
            Proto     => 'tcp',
        );
        return ($srv, $p) if $srv;
    }
    die "cannot bind 127.0.0.1:$port\n";
}

sub cloexec {
    my ($fh) = @_;
    # Windows Fcntl has no F_GETFD. Child processes are started with system(1).
    return if $^O eq 'MSWin32';
    my $flags = fcntl($fh, F_GETFD, 0);
    fcntl($fh, F_SETFD, ($flags || 0) | FD_CLOEXEC) if defined $flags;
}

sub open_browser {
    my ($url) = @_;
    if ($^O eq 'MSWin32') {
        system(1, 'cmd.exe', '/c', "start \"\" \"$url\"");
        return;
    }
    my $pid = fork();
    return unless defined $pid && $pid == 0;
    my $grand = fork();
    exit 0 if !defined $grand || $grand;
    if ($^O eq 'darwin') {
        exec 'open', $url;
    } else {
        exec 'xdg-open', $url;
    }
    exit 0;
}

sub handle_client {
    my ($client) = @_;
    my $req = read_request($client);
    return unless $req;
    my ($method, $path, $query, $headers, $body) = @$req;
    $path =~ s{//+}{/}g;
    $path =~ s{/\z}{} unless $path eq '/';

    if ($method eq 'GET' && ($path eq '/' || $path eq '/index.html')) {
        return send_static($client, 'index.html');
    }
    if ($method eq 'GET' && $path =~ m{\A/(app\.(?:js|css)|favicon\.svg)\z}) {
        return send_static($client, $1);
    }
    if ($method eq 'GET' && $path =~ m{\A/media/canvas/([A-Za-z0-9][A-Za-z0-9_-]{0,40})\.jpg\z}) {
        my $file = File::Spec->catfile($ROOT, 'canvas', "$1.jpg");
        die "404 找不到背景 / canvas not found\n" unless -f $file;
        return send_file($client, $file, 'image/jpeg', "$1.jpg", 0, 3600);
    }
    if ($method eq 'GET' && $path =~ m{\A/media/cover/([A-Za-z0-9][A-Za-z0-9_-]{0,40})\.jpg\z}) {
        my $file = File::Spec->catfile(book_dir($1), 'cover.jpg');
        die "404 找不到封面 / cover not found\n" unless -f $file;
        return send_file($client, $file, 'image/jpeg', 'cover.jpg', 0, 0);
    }
    if ($method eq 'GET' && $path eq '/api/health') {
        return send_json($client, 200, 'OK', health());
    }
    if ($method eq 'GET' && $path eq '/api/catalog') {
        return send_json($client, 200, 'OK', catalog());
    }
    if ($method eq 'GET' && $path eq '/api/books') {
        return send_json($client, 200, 'OK', { books => list_books() });
    }
    if ($method eq 'POST' && $path eq '/api/books') {
        my $data = decode_json_body($body);
        my $id = create_book($data);
        return send_json($client, 201, 'Created', book_detail($id));
    }
    if ($method eq 'POST' && $path eq '/api/fonts') {
        my $name = header_filename($headers->{'x-filename'} || '');
        die "400 字體檔名需以 .ttf .otf 或 .ttc 結尾 / bad font name\n"
            unless $name =~ /\.(ttf|otf|ttc)\z/i;
        die "400 空檔案 / empty file\n" unless defined $body && length $body;
        my $dest = File::Spec->catfile($ROOT, 'fonts', $name);
        spew_raw($dest, $body);
        return send_json($client, 201, 'Created', { name => $name, bytes => length $body });
    }
    if ($method eq 'POST' && $path eq '/api/canvases') {
        my $id = $headers->{'x-canvas-id'} || '';
        my $src = $headers->{'x-source-canvas'} || '';
        $id =~ s/^\s+|\s+$//g;
        $src =~ s/^\s+|\s+$//g;
        die "400 底圖 ID 不合法 / bad canvas id\n" unless valid_id($id);
        die "400 來源書葉不合法 / bad source canvas\n" unless valid_id($src);
        die "400 請上傳 JPEG / JPEG required\n" unless defined $body && $body =~ /^\xFF\xD8\xFF/;
        my $src_cfg = File::Spec->catfile($ROOT, 'canvas', "$src.cfg");
        die "404 找不到來源書葉 / source canvas not found\n" unless -f $src_cfg;
        my $cfg = File::Spec->catfile($ROOT, 'canvas', "$id.cfg");
        my $jpg = File::Spec->catfile($ROOT, 'canvas', "$id.jpg");
        copy($src_cfg, $cfg) or die "500 無法複製書葉設定 / copy failed\n";
        spew_raw($jpg, $body);
        return send_json($client, 201, 'Created', { id => $id });
    }
    if ($method eq 'POST' && $path eq '/api/jobs') {
        my $data = decode_json_body($body);
        my $job = start_job($data);
        return send_json($client, 201, 'Created', $job);
    }

    if ($path =~ m{\A/api/books/([A-Za-z0-9][A-Za-z0-9_-]{0,40})(.*)\z}) {
        my ($id, $rest) = ($1, $2);
        die "404 找不到書籍 / book not found\n" unless book_exists($id);
        if ($rest eq '' && $method eq 'GET') {
            return send_json($client, 200, 'OK', book_detail($id));
        }
        if ($rest eq '' && $method eq 'DELETE') {
            delete_book($id);
            return send_json($client, 200, 'OK', { ok => JSON::PP::true });
        }
        if ($rest eq '/config' && $method eq 'PUT') {
            save_config($id, decode_json_body($body));
            return send_json($client, 200, 'OK', book_detail($id));
        }
        if ($rest eq '/cover' && $method eq 'POST') {
            die "400 請上傳 JPEG / JPEG required\n" unless defined $body && $body =~ /^\xFF\xD8\xFF/;
            spew_raw(File::Spec->catfile(book_dir($id), 'cover.jpg'), $body);
            return send_json($client, 201, 'Created', { ok => JSON::PP::true });
        }
        if ($rest eq '/pdf' && $method eq 'GET') {
            my $name = query_param($query, 'name');
            die "400 缺少檔名 / missing name\n" unless defined $name && $name ne '';
            die "400 檔名不合法 / bad name\n" if $name =~ m{[/\\]} || $name =~ /\.\./ || $name !~ /\.pdf\z/i;
            my $file = File::Spec->catfile(book_dir($id), $name);
            die "404 找不到 PDF / PDF not found\n" unless -f $file;
            my $download = query_param($query, 'download') ? 1 : 0;
            return send_file($client, $file, 'application/pdf', $name, $download, 0);
        }
        if ($rest =~ m{\A/text/([^/]+)\z}) {
            my $name = $1;
            $name =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
            $name = decode('UTF-8', $name, FB_DEFAULT);
            die "400 文本檔名不合法 / bad text name\n" unless valid_text_name($name);
            my $file = File::Spec->catfile(book_dir($id), 'text', $name);
            if ($method eq 'GET') {
                die "404 找不到文本 / text not found\n" unless -f $file;
                return send_json($client, 200, 'OK', {
                    name => $name,
                    text => decode('UTF-8', slurp_raw($file), FB_DEFAULT),
                });
            }
            if ($method eq 'PUT') {
                my $data = decode_json_body($body);
                my $text = defined $data->{text} ? $data->{text} : '';
                die "400 文本不是字串 / text must be a string\n" if ref $text;
                make_path(File::Spec->catdir(book_dir($id), 'text'));
                my $bytes = encode('UTF-8', $text);
                $bytes =~ s/\r\n/\n/g;
                $bytes .= "\n" if length($bytes) && $bytes !~ /\n\z/;
                spew_raw($file, $bytes);
                return send_json($client, 200, 'OK', { name => $name, bytes => length $bytes });
            }
        }
    }

    if ($method eq 'GET' && $path =~ m{\A/api/jobs/([A-Za-z0-9_-]+)\z}) {
        return send_json($client, 200, 'OK', job_status($1));
    }

    die "404 找不到 / not found\n";
}

sub read_request {
    my ($client) = @_;
    my $buf = '';
    while ($buf !~ /\r\n\r\n/s) {
        my $n = sysread($client, my $chunk, 8192);
        return unless defined $n && $n > 0;
        $buf .= $chunk;
        die "400 標頭過大 / headers too large\n" if length($buf) > 65536 && $buf !~ /\r\n\r\n/s;
    }
    my ($head, $rest) = split /\r\n\r\n/, $buf, 2;
    $rest = '' unless defined $rest;
    my @lines = split /\r\n/, $head;
    my $reqline = shift @lines || '';
    my ($method, $target) = split / /, $reqline, 3;
    die "400 錯誤的請求 / bad request\n" unless $method && defined $target;
    my %headers;
    for my $line (@lines) {
        my ($k, $v) = split /:\s*/, $line, 2;
        next unless defined $k;
        $headers{lc $k} = defined $v ? $v : '';
    }
    my ($path, $query) = split /\?/, $target, 2;
    $query = '' unless defined $query;
    $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    my $len = 0;
    if (exists $headers{'content-length'}) {
        die "400 長度不合法 / bad length\n" unless $headers{'content-length'} =~ /^\d+\z/;
        $len = 0 + $headers{'content-length'};
        die "413 檔案過大 / body too large\n" if $len > 80 * 1024 * 1024;
    } elsif ($method eq 'POST' || $method eq 'PUT') {
        die "411 需要 Content-Length / length required\n";
    }
    my $need = $len - length($rest);
    while ($need > 0) {
        my $chunk_size = $need > 65536 ? 65536 : $need;
        my $n = sysread($client, my $chunk, $chunk_size);
        die "400 內容不完整 / truncated body\n" unless defined $n && $n > 0;
        $rest .= $chunk;
        $need -= $n;
    }
    my $body = $len ? substr($rest, 0, $len) : '';
    return [$method, $path, $query, \%headers, $body];
}

sub decode_json_body {
    my ($body) = @_;
    my $data = eval { $JSON->decode($body || '') };
    die "400 JSON 無法解析 / invalid JSON\n" if $@ || ref $data ne 'HASH';
    return $data;
}

sub send_json {
    my ($client, $code, $text, $data) = @_;
    my $bytes = $JSON->encode($data);
    send_bytes($client, $code, $text, 'application/json; charset=utf-8', $bytes, 0);
}

sub send_static {
    my ($client, $name) = @_;
    my $path = File::Spec->catfile($ROOT, 'web', 'public', $name);
    die "404 找不到 / not found\n" unless -f $path;
    my $ext = ($name =~ /\.([A-Za-z0-9]+)\z/) ? lc $1 : '';
    my %types = (
        html => 'text/html; charset=utf-8',
        js   => 'text/javascript; charset=utf-8',
        css  => 'text/css; charset=utf-8',
        svg  => 'image/svg+xml',
    );
    send_file($client, $path, $types{$ext} || 'application/octet-stream', $name, 0, 0);
}

sub send_file {
    my ($client, $path, $type, $name, $download, $cache) = @_;
    my $size = -s $path;
    $size = 0 unless defined $size;
    open my $fh, '<:raw', $path or die "404 找不到 / not found\n";
    my $ascii = $name;
    $ascii =~ s/[^\x20-\x7E]/_/g;
    $ascii =~ s/"/_/g;
    my $star = pct_encode(encode('UTF-8', $name));
    my $disp = $download ? 'attachment' : 'inline';
    print $client "HTTP/1.1 200 OK\r\n";
    print $client "Content-Type: $type\r\n";
    print $client "Content-Length: $size\r\n";
    print $client "Content-Disposition: $disp; filename=\"$ascii\"; filename*=UTF-8''$star\r\n";
    print $client "Cache-Control: " . ($cache ? "public, max-age=$cache" : "no-store") . "\r\n";
    print $client "X-Content-Type-Options: nosniff\r\n";
    print $client "Connection: close\r\n\r\n";
    my $buf;
    while (read($fh, $buf, 65536)) {
        print $client $buf or last;
    }
    close $fh;
}

sub send_bytes {
    my ($client, $code, $text, $type, $bytes, $cache) = @_;
    $bytes = '' unless defined $bytes;
    print $client "HTTP/1.1 $code $text\r\n";
    print $client "Content-Type: $type\r\n";
    print $client "Content-Length: " . length($bytes) . "\r\n";
    print $client "Cache-Control: no-store\r\n";
    print $client "X-Content-Type-Options: nosniff\r\n";
    print $client "Connection: close\r\n\r\n";
    print $client $bytes;
}

sub status_text {
    my ($code) = @_;
    return 'OK' if $code == 200;
    return 'Created' if $code == 201;
    return 'Bad Request' if $code == 400;
    return 'Forbidden' if $code == 403;
    return 'Not Found' if $code == 404;
    return 'Conflict' if $code == 409;
    return 'Length Required' if $code == 411;
    return 'Payload Too Large' if $code == 413;
    return 'Error';
}

sub pct_encode {
    my ($bytes) = @_;
    $bytes =~ s/([^A-Za-z0-9._~-])/sprintf('%%%02X', ord($1))/ge;
    return $bytes;
}

sub query_param {
    my ($query, $key) = @_;
    return '' unless defined $query && length $query;
    for my $pair (split /&/, $query) {
        my ($k, $v) = split /=/, $pair, 2;
        next unless defined $k;
        $k =~ tr/+/ /;
        $k =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        next unless $k eq $key;
        $v = '' unless defined $v;
        $v =~ tr/+/ /;
        $v =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        return decode('UTF-8', $v, FB_DEFAULT);
    }
    return '';
}

sub header_filename {
    my ($name) = @_;
    $name = decode('UTF-8', $name, FB_DEFAULT);
    $name =~ s/\\/\//g;
    $name =~ s{^.*/}{};
    $name =~ s/^\s+|\s+$//g;
    die "400 檔名不合法 / bad filename\n" if $name eq '' || $name =~ m{[/\\]} || $name =~ /\.\./ || $name =~ /[\r\n\0]/;
    return $name;
}

sub valid_id {
    my ($id) = @_;
    return defined $id && $id =~ /\A[A-Za-z0-9][A-Za-z0-9_-]{0,40}\z/;
}

sub valid_text_name {
    my ($name) = @_;
    return defined $name && $name =~ /\A[0-9A-Za-z][0-9A-Za-z_.-]{0,48}\.txt\z/i;
}

sub book_dir {
    my ($id) = @_;
    die "400 書籍 ID 不合法 / bad book id\n" unless valid_id($id);
    return File::Spec->catdir($ROOT, 'books', $id);
}

sub book_exists {
    my ($id) = @_;
    return 0 unless valid_id($id);
    return -f File::Spec->catfile(book_dir($id), 'book.cfg');
}

sub protected_book {
    my ($id) = @_;
    return $id eq 'sample' || $id eq '01';
}

sub jobs_root {
    return File::Spec->catdir($ROOT, 'web', 'jobs');
}

sub slurp_raw {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "500 無法讀取 / cannot read\n";
    local $/;
    my $data = <$fh>;
    close $fh;
    return defined $data ? $data : '';
}

sub spew_raw {
    my ($path, $bytes) = @_;
    my $tmp = $path . '.writing';
    open my $fh, '>:raw', $tmp or die "500 無法寫入 / cannot write\n";
    print $fh $bytes or die "500 無法寫入 / cannot write\n";
    close $fh or die "500 無法寫入 / cannot write\n";
    rename $tmp, $path or die "500 無法寫入 / cannot write\n";
}

sub parse_cfg_file {
    my ($path) = @_;
    die "404 找不到設定 / config not found\n" unless -f $path;
    my $bytes = slurp_raw($path);
    $bytes =~ s/^\xEF\xBB\xBF//;
    my %cfg;
    for my $line (split /\n/, $bytes, -1) {
        $line =~ s/\r\z//;
        next if $line =~ /^\s*\z/;
        next if $line =~ /^\s*#/;
        my $work = $line;
        $work =~ s/#.*\z// unless $work =~ /=#/;
        $work =~ s/\s//g;
        next if $work eq '';
        my ($k, $v) = split /=/, $work, 2;
        next unless defined $k && $k ne '';
        $v = '' unless defined $v;
        $cfg{decode('UTF-8', $k, FB_DEFAULT)} = decode('UTF-8', $v, FB_DEFAULT);
    }
    return \%cfg;
}

sub assert_cfg {
    my ($cfg) = @_;
    die "400 缺少書名 title / missing title\n" unless defined $cfg->{title} && $cfg->{title} ne '';
    die "400 缺少 canvas_id / missing canvas\n" unless defined $cfg->{canvas_id} && $cfg->{canvas_id} ne '';
    my $cid = $cfg->{canvas_id};
    die "400 書葉 ID 不合法 / bad canvas id\n" unless valid_id($cid);
    my $jpg = File::Spec->catfile($ROOT, 'canvas', "$cid.jpg");
    my $ccfg = File::Spec->catfile($ROOT, 'canvas', "$cid.cfg");
    die "400 找不到書葉背景 / canvas not found\n" unless -f $jpg && -f $ccfg;
    die "400 未設定主字體 font1 / font1 required\n" unless defined $cfg->{font1} && $cfg->{font1} ne '';
    for my $i (1 .. 5) {
        my $font = $cfg->{"font$i"};
        next unless defined $font && $font ne '';
        die "400 字體檔名不合法 / bad font name\n" if $font =~ m{[/\\]} || $font =~ /\.\./;
        my $file = File::Spec->catfile($ROOT, 'fonts', $font);
        die "400 找不到字體 $font / font missing\n" unless -f $file;
    }
    if (defined $cfg->{row_num} && $cfg->{row_num} ne '' && $cfg->{row_num} !~ /\A[1-9]\d*\z/) {
        die "400 每列字數必須是正整數 / row_num must be a positive integer\n";
    }
}

sub update_cfg_file {
    my ($path, $values) = @_;
    my $text = decode('UTF-8', slurp_raw($path), FB_DEFAULT);
    $text =~ s/^\x{FEFF}//;
    my @lines = split /\n/, $text, -1;
    for my $key (sort keys %$values) {
        next unless $key =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/;
        my $val = $values->{$key};
        $val = '' unless defined $val;
        die "400 設定值不能換行 / value cannot contain newlines\n" if $val =~ /[\r\n]/;
        die "400 設定值過長 / value too long\n" if length($val) > 4000;
        my $found = 0;
        for my $line (@lines) {
            next unless defined $line;
            if ($line =~ /^\Q$key\E=/) {
                if ($found) {
                    $line = undef;
                } else {
                    $line = "$key=$val";
                    $found = 1;
                }
            }
        }
        @lines = grep { defined } @lines;
        push @lines, "$key=$val" unless $found;
    }
    my $out = join("\n", @lines);
    $out .= "\n" unless $out =~ /\n\z/;
    spew_raw($path, encode('UTF-8', $out));
}

sub write_raw_cfg {
    my ($path, $text) = @_;
    die "400 設定不是字串 / config must be a string\n" if ref $text;
    $text = '' unless defined $text;
    die "400 設定檔過大 / config too large\n" if length($text) > 200000;
    $text =~ s/^\x{FEFF}//;
    $text =~ s/\r\n/\n/g;
    $text =~ s/\r/\n/g;
    $text .= "\n" unless $text =~ /\n\z/;
    my $bytes = encode('UTF-8', $text);
    my $tmp = $path . '.writing';
    spew_raw($tmp, $bytes);
    my $cfg = eval { parse_cfg_file($tmp) };
    if ($@) {
        unlink $tmp;
        die $@;
    }
    eval { assert_cfg($cfg) };
    if ($@) {
        unlink $tmp;
        die $@;
    }
    rename $tmp, $path or die "500 無法寫入 / cannot write\n";
}

sub list_books {
    my $dir = File::Spec->catdir($ROOT, 'books');
    opendir my $dh, $dir or return [];
    my @books;
    while (my $name = readdir $dh) {
        next if $name =~ /\A\./;
        next unless valid_id($name);
        my $cfg_path = File::Spec->catfile($dir, $name, 'book.cfg');
        next unless -f $cfg_path;
        my $cfg = eval { parse_cfg_file($cfg_path) } || {};
        push @books, {
            id        => $name,
            title     => $cfg->{title} || '',
            author    => $cfg->{author} || '',
            canvas    => $cfg->{canvas_id} || '',
            protected => protected_book($name) ? JSON::PP::true : JSON::PP::false,
        };
    }
    closedir $dh;
    @books = sort {
        if ($a->{id} eq 'sample') { -1 }
        elsif ($b->{id} eq 'sample') { 1 }
        else { $a->{id} cmp $b->{id} }
    } @books;
    return \@books;
}

sub list_canvases {
    my $dir = File::Spec->catdir($ROOT, 'canvas');
    opendir my $dh, $dir or return [];
    my @items;
    while (my $name = readdir $dh) {
        next unless $name =~ /\A([A-Za-z0-9][A-Za-z0-9_-]{0,40})\.cfg\z/;
        my $id = $1;
        next unless -f File::Spec->catfile($dir, "$id.jpg");
        my $cfg = eval { parse_cfg_file(File::Spec->catfile($dir, $name)) } || {};
        push @items, {
            id      => $id,
            width   => $cfg->{canvas_width} || '',
            height  => $cfg->{canvas_height} || '',
            columns => $cfg->{leaf_col} || '',
            logo    => $cfg->{logo_text} || '',
        };
    }
    closedir $dh;
    @items = sort { $a->{id} cmp $b->{id} } @items;
    return \@items;
}

sub list_fonts {
    my $dir = File::Spec->catdir($ROOT, 'fonts');
    opendir my $dh, $dir or return [];
    my @fonts;
    while (my $name = readdir $dh) {
        next if $name =~ /\A\./;
        next unless $name =~ /\.(ttf|otf|ttc)\z/i;
        next if $name =~ m{[/\\]};
        my $path = File::Spec->catfile($dir, $name);
        next unless -f $path;
        push @fonts, { name => decode('UTF-8', $name, FB_DEFAULT), bytes => -s $path };
    }
    closedir $dh;
    @fonts = sort { $a->{name} cmp $b->{name} } @fonts;
    return \@fonts;
}

sub list_texts {
    my ($id) = @_;
    my $dir = File::Spec->catdir(book_dir($id), 'text');
    return [] unless -d $dir;
    opendir my $dh, $dir or return [];
    my @texts;
    while (my $name = readdir $dh) {
        next if $name =~ /\A\./;
        my $decoded = decode('UTF-8', $name, FB_DEFAULT);
        next unless valid_text_name($decoded);
        my $path = File::Spec->catfile($dir, $name);
        next unless -f $path;
        push @texts, { name => $decoded, bytes => -s $path };
    }
    closedir $dh;
    @texts = sort { $a->{name} cmp $b->{name} } @texts;
    return \@texts;
}

sub list_pdfs {
    my ($id) = @_;
    my $dir = book_dir($id);
    opendir my $dh, $dir or return [];
    my @pdfs;
    while (my $name = readdir $dh) {
        next if $name =~ /\A\./;
        my $decoded = decode('UTF-8', $name, FB_DEFAULT);
        next unless $decoded =~ /\.pdf\z/i;
        next if $decoded =~ m{[/\\]} || $decoded =~ /\.\./;
        my $path = File::Spec->catfile($dir, $name);
        next unless -f $path;
        push @pdfs, {
            name  => $decoded,
            bytes => -s $path,
            mtime => (stat($path))[9] || 0,
        };
    }
    closedir $dh;
    @pdfs = sort { $b->{mtime} <=> $a->{mtime} || $a->{name} cmp $b->{name} } @pdfs;
    return \@pdfs;
}

sub book_detail {
    my ($id) = @_;
    die "404 找不到書籍 / book not found\n" unless book_exists($id);
    my $cfg_path = File::Spec->catfile(book_dir($id), 'book.cfg');
    my $cfg = parse_cfg_file($cfg_path);
    return {
        id        => $id,
        protected => protected_book($id) ? JSON::PP::true : JSON::PP::false,
        config    => $cfg,
        raw       => decode('UTF-8', slurp_raw($cfg_path), FB_DEFAULT),
        texts     => list_texts($id),
        pdfs      => list_pdfs($id),
        hasCover  => (-f File::Spec->catfile(book_dir($id), 'cover.jpg')) ? JSON::PP::true : JSON::PP::false,
    };
}

sub catalog {
    return {
        books    => list_books(),
        canvases => list_canvases(),
        fonts    => list_fonts(),
    };
}

sub health {
    my $err = '';
    my $ok = eval {
        require PDF::Builder;
        require Font::FreeType;
        1;
    };
    if (!$ok) {
        $err = "$@";
        $err =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
        $err =~ s/\s+\z//;
        $err = substr($err, 0, 300);
    }
    return {
        ok            => JSON::PP::true,
        engine        => 'vRain',
        engineVersion => $ENGINE_VERSION,
        webVersion    => $WEB_VERSION,
        perl          => sprintf('%vd', $^V),
        platform      => $^O,
        arch          => $Config{archname},
        port          => $PORT,
        ghostscript   => has_gs() ? JSON::PP::true : JSON::PP::false,
        modules       => $ok ? JSON::PP::true : JSON::PP::false,
        moduleError   => $err,
    };
}

sub has_cmd {
    my ($name) = @_;
    my $sep = $^O eq 'MSWin32' ? ';' : ':';
    my @ext = $^O eq 'MSWin32'
        ? split(/;/, ($ENV{PATHEXT} || '.COM;.EXE;.BAT;.CMD'))
        : ('');
    for my $dir (split /\Q$sep\E/, ($ENV{PATH} || '')) {
        next if !defined $dir || $dir eq '';
        for my $ext (@ext) {
            my $path = File::Spec->catfile($dir, $name . $ext);
            return 1 if -f $path && ($^O eq 'MSWin32' || -x $path);
        }
    }
    return 0;
}

sub has_gs {
    return has_cmd('gs') || has_cmd('gswin64c') || has_cmd('gswin32c');
}

sub create_book {
    my ($data) = @_;
    my $id = $data->{id} || '';
    die "400 書籍 ID 不合法 / bad book id\n" unless valid_id($id);
    die "409 書籍已存在 / book exists\n" if book_exists($id) || -e book_dir($id);
    my $template = $data->{template} || 'sample';
    die "400 範本不合法 / bad template\n" unless valid_id($template);
    my $src = File::Spec->catfile(book_dir($template), 'book.cfg');
    die "404 找不到範本 / template not found\n" unless -f $src;
    my $dir = book_dir($id);
    make_path(File::Spec->catdir($dir, 'text'));
    copy($src, File::Spec->catfile($dir, 'book.cfg')) or die "500 無法建立書籍 / cannot create book\n";
    my %over;
    $over{title} = $data->{title} if defined $data->{title} && !ref $data->{title};
    $over{author} = $data->{author} if defined $data->{author} && !ref $data->{author};
    $over{canvas_id} = $data->{canvas_id} if defined $data->{canvas_id} && !ref $data->{canvas_id};
    update_cfg_file(File::Spec->catfile($dir, 'book.cfg'), \%over) if %over;
    my $created = eval { assert_cfg(parse_cfg_file(File::Spec->catfile($dir, 'book.cfg'))); 1 };
    if (!$created) {
        my $err = $@;
        remove_tree($dir);
        die $err;
    }
    my $text = defined $data->{text} && !ref $data->{text} ? $data->{text} : '';
    my $bytes = encode('UTF-8', $text);
    $bytes .= "\n" if length($bytes) && $bytes !~ /\n\z/;
    spew_raw(File::Spec->catfile($dir, 'text', '01.txt'), $bytes);
    return $id;
}

sub delete_book {
    my ($id) = @_;
    die "403 範例書不能刪除 / sample books are kept\n" if protected_book($id);
    die "409 這本書正在排版 / book is generating\n" if job_busy_for($id);
    my $dir = book_dir($id);
    die "404 找不到書籍 / book not found\n" unless -d $dir;
    die "400 拒絕刪除連結 / refusing to delete a symlink\n" if -l $dir;
    remove_tree($dir) or die "500 無法刪除 / cannot delete\n";
}

sub save_config {
    my ($id, $data) = @_;
    my $path = File::Spec->catfile(book_dir($id), 'book.cfg');
    if (exists $data->{raw}) {
        write_raw_cfg($path, $data->{raw});
        return;
    }
    my $values = $data->{values};
    die "400 缺少 values / missing values\n" unless ref $values eq 'HASH';
    my $cfg = parse_cfg_file($path);
    for my $key (keys %$values) {
        next unless $key =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/;
        my $val = $values->{$key};
        die "400 設定值必須是字串或數字 / value must be a string\n" if ref $val;
        $val = '' unless defined $val;
        die "400 設定值不能換行 / value cannot contain newlines\n" if $val =~ /[\r\n]/;
        $cfg->{$key} = "$val";
    }
    assert_cfg($cfg);
    update_cfg_file($path, $values);
}

sub start_job {
    my ($data) = @_;
    my $id = $data->{book} || '';
    die "404 找不到書籍 / book not found\n" unless book_exists($id);
    my $cfg = parse_cfg_file(File::Spec->catfile(book_dir($id), 'book.cfg'));
    assert_cfg($cfg);
    my $from = defined $data->{from} ? $data->{from} : 1;
    my $to = defined $data->{to} ? $data->{to} : 1;
    my $test = defined $data->{testPages} ? $data->{testPages} : 0;
    die "400 序號必須是正整數 / from and to must be positive integers\n"
        unless "$from" =~ /\A[1-9]\d*\z/ && "$to" =~ /\A[1-9]\d*\z/ && $from <= $to && $to <= 9999;
    die "400 測試頁數不合法 / bad test page count\n"
        unless "$test" =~ /\A\d+\z/ && $test <= 500;
    my $compress = $data->{compress} ? 1 : 0;
    die "400 未找到 Ghostscript，不能壓縮 / Ghostscript not found\n" if $compress && !has_gs();

    my $cur = read_current();
    if ($cur && process_alive($cur->{pid})) {
        die "409 已有排版工作在執行 / a job is already running\n";
    }

    cleanup_jobs();
    my $job = strftime('%Y%m%d%H%M%S', localtime) . "-$$-" . int(rand(1000));
    my $dir = File::Spec->catdir(jobs_root(), $job);
    make_path($dir);
    my $log = File::Spec->catfile($dir, 'log.txt');
    my %before;
    for my $pdf (@{ list_pdfs($id) }) {
        $before{$pdf->{name}} = $pdf->{mtime};
    }
    my $meta = {
        id         => $job,
        pid        => 0,
        book       => $id,
        from       => 0 + $from,
        to         => 0 + $to,
        testPages  => 0 + $test,
        compress   => $compress ? JSON::PP::true : JSON::PP::false,
        started    => time,
        pdfsBefore => \%before,
    };
    write_json(File::Spec->catfile($dir, 'meta.json'), $meta);
    my $header = "vRain Web job $job book=$id from=$from to=$to testPages=$test\n";
    spew_raw($log, encode('UTF-8', $header));

    my @cmd = ($^X, File::Spec->catfile($ROOT, 'vrain.pl'), '-b', $id, '-f', "$from", '-t', "$to");
    push @cmd, '-z', "$test" if $test > 0;
    push @cmd, '-c' if $compress;
    my $pid = spawn($log, @cmd);
    $meta->{pid} = $pid;
    write_json(File::Spec->catfile($dir, 'meta.json'), $meta);
    spew_raw(File::Spec->catfile(jobs_root(), 'current'), $job);
    return { id => $job, status => 'running' };
}

sub spawn {
    my ($log, @cmd) = @_;
    my $runner = File::Spec->catfile($ROOT, 'web', 'run.pl');
    if ($^O eq 'MSWin32') {
        my $pid = system(1, $^X, $runner, $log, $ROOT, @cmd);
        die "500 無法啟動排版 / failed to start typesetter\n" if !$pid || $pid < 0;
        return $pid;
    }
    my $pid = fork();
    die "500 無法啟動排版 / fork failed\n" unless defined $pid;
    if ($pid == 0) {
        close $SERVER if $SERVER;
        exec $^X, $runner, $log, $ROOT, @cmd;
        exit 1;
    }
    return $pid;
}

sub write_json {
    my ($path, $data) = @_;
    spew_raw($path, $JSON->encode($data));
}

sub read_json {
    my ($path) = @_;
    return undef unless -f $path;
    my $data = eval { $JSON->decode(slurp_raw($path)) };
    return undef if $@ || ref $data ne 'HASH';
    return $data;
}

sub read_current {
    my $path = File::Spec->catfile(jobs_root(), 'current');
    return undef unless -f $path;
    my $id = slurp_raw($path);
    $id =~ s/\s+//g;
    return undef unless $id =~ /\A[A-Za-z0-9_-]+\z/;
    return read_json(File::Spec->catfile(jobs_root(), $id, 'meta.json'));
}

sub job_busy_for {
    my ($book) = @_;
    my $cur = read_current();
    return 0 unless $cur && $cur->{book} && $cur->{book} eq $book;
    return process_alive($cur->{pid});
}

sub process_alive {
    my ($pid) = @_;
    return 0 unless defined $pid && "$pid" =~ /\A\d+\z/ && $pid > 0;
    my $got = waitpid($pid, WNOHANG);
    return 0 if $got == $pid;
    return kill(0, $pid) ? 1 : 0;
}

sub job_status {
    my ($id) = @_;
    die "400 工作 ID 不合法 / bad job id\n" unless $id =~ /\A[A-Za-z0-9_-]+\z/;
    my $dir = File::Spec->catdir(jobs_root(), $id);
    my $meta = read_json(File::Spec->catfile($dir, 'meta.json'));
    die "404 找不到工作 / job not found\n" unless $meta;
    my $log = '';
    my $log_path = File::Spec->catfile($dir, 'log.txt');
    if (-f $log_path) {
        $log = decode('UTF-8', slurp_raw($log_path), FB_DEFAULT);
        $log = substr($log, -120000) if length($log) > 120000;
    }
    my $alive = process_alive($meta->{pid});
    my $pdfs = list_pdfs($meta->{book});
    my $before = $meta->{pdfsBefore} || {};
    my $fresh = 0;
    for my $pdf (@$pdfs) {
        my $old = $before->{$pdf->{name}};
        $fresh = 1 if !defined $old || $pdf->{mtime} >= ($meta->{started} || 0);
    }
    my $status = 'running';
    if (!$alive) {
        if ($fresh || $log =~ /完成！/) {
            $status = 'done';
        } else {
            $status = 'error';
        }
    }
    return {
        id        => $id,
        status    => $status,
        book      => $meta->{book},
        from      => $meta->{from},
        to        => $meta->{to},
        testPages => $meta->{testPages},
        log       => $log,
        pdfs      => $pdfs,
    };
}

sub cleanup_jobs {
    my $root = jobs_root();
    opendir my $dh, $root or return;
    my @ids;
    while (my $name = readdir $dh) {
        next unless $name =~ /\A\d{14}-/;
        push @ids, $name;
    }
    closedir $dh;
    @ids = sort @ids;
    while (@ids > 12) {
        my $old = shift @ids;
        remove_tree(File::Spec->catdir($root, $old));
    }
}

sub self_check {
    die "sample book missing\n" unless book_exists('sample');
    my $cfg = parse_cfg_file(File::Spec->catfile(book_dir('sample'), 'book.cfg'));
    die "sample title missing\n" unless $cfg->{title};
    die "sample canvas missing\n" unless -f File::Spec->catfile($ROOT, 'canvas', $cfg->{canvas_id} . '.jpg');
    die "sample font missing\n" unless -f File::Spec->catfile($ROOT, 'fonts', $cfg->{font1});
    die "no canvases\n" unless @{ list_canvases() };
    die "no fonts\n" unless @{ list_fonts() };
    die "no texts\n" unless @{ list_texts('sample') };
    die "db missing\n" unless -f File::Spec->catfile($ROOT, 'db', 'num2zh_jid.txt');
    die "ui missing\n" unless -f File::Spec->catfile($ROOT, 'web', 'public', 'index.html');
    my $tmp = File::Spec->catdir(jobs_root(), "selfcheck-$$");
    make_path($tmp);
    my $copy = File::Spec->catfile($tmp, 'book.cfg');
    copy(File::Spec->catfile(book_dir('sample'), 'book.cfg'), $copy) or die "copy failed\n";
    update_cfg_file($copy, { title => '測試甲', row_num => '12' });
    my $again = parse_cfg_file($copy);
    die "roundtrip title\n" unless $again->{title} eq '測試甲';
    die "roundtrip row\n" unless $again->{row_num} eq '12';
    die "roundtrip font\n" unless $again->{font1} eq $cfg->{font1};
    remove_tree($tmp);
    print "self-check ok\n";
    return 0;
}
