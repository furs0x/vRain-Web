//go:build !windows

package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"syscall"
)

func configure(cmd *exec.Cmd) {}

func acquire(path string) (func(), error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		f.Close()
		return nil, err
	}
	return func() {
		_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
		f.Close()
	}, nil
}

func openBrowser(page string) error {
	name := "xdg-open"
	if runtime.GOOS == "darwin" {
		name = "/usr/bin/open"
	} else if exists("/usr/bin/xdg-open") {
		name = "/usr/bin/xdg-open"
	}
	cmd := exec.Command(name, page)
	if err := cmd.Start(); err != nil {
		return err
	}
	go cmd.Wait()
	return nil
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func report(err error) {
	msg := err.Error()
	fmt.Fprintln(os.Stderr, "兀雨 vRain:", msg)
	if runtime.GOOS == "darwin" && exists("/usr/bin/osascript") {
		script := fmt.Sprintf("display dialog %q with title \"兀雨 vRain\" buttons {\"好\"} with icon stop", msg)
		_ = exec.Command("/usr/bin/osascript", "-e", script).Run()
		return
	}
	cmd := exec.Command("notify-send", "兀雨 vRain", msg)
	_ = cmd.Run()
}

func watchSignals(cmd *exec.Cmd) {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-ch
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
	}()
}
