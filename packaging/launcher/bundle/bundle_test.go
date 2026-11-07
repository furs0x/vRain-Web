package bundle

import (
	"os"
	"path/filepath"
	"testing"
)

func TestPackExtractRoundTrip(t *testing.T) {
	dir := t.TempDir()
	stage := filepath.Join(dir, "stage")
	if err := os.MkdirAll(filepath.Join(stage, "web"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(stage, "canvas"), 0o755); err != nil {
		t.Fatal(err)
	}
	body := []byte("print \"ok\\n\";\n")
	if err := os.WriteFile(filepath.Join(stage, "web", "server.pl"), body, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stage, "canvas", "skip.pl"), []byte("nope"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("server.pl", filepath.Join(stage, "web", "alias.pl")); err != nil {
		t.Fatal(err)
	}
	launcher := filepath.Join(dir, "launcher")
	if err := os.WriteFile(launcher, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	out := filepath.Join(dir, "app.bin")
	if err := Pack(launcher, stage, out); err != nil {
		t.Fatal(err)
	}
	if _, err := Locate(out); err != nil {
		t.Fatal(err)
	}
	dest := filepath.Join(dir, "out")
	if err := Extract(out, dest); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(dest, "web", "server.pl"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(body) {
		t.Fatalf("body %q", got)
	}
	if _, err := os.Stat(filepath.Join(dest, "canvas", "skip.pl")); !os.IsNotExist(err) {
		t.Fatalf("canvas script should be omitted: %v", err)
	}
	link, err := os.Readlink(filepath.Join(dest, "web", "alias.pl"))
	if err != nil {
		t.Fatal(err)
	}
	if link != "server.pl" {
		t.Fatalf("link %s", link)
	}
	if err := Extract(out, dest); err != nil {
		t.Fatal(err)
	}
}
