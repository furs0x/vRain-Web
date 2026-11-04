//go:build windows

package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
	"unsafe"
)

func configure(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}
}

func acquire(path string) (func(), error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return nil, err
	}
	proc := syscall.NewLazyDLL("kernel32.dll").NewProc("LockFileEx")
	const lockfileExclusive = 2
	r, _, e := proc.Call(
		f.Fd(),
		lockfileExclusive,
		0,
		1,
		0,
		0,
	)
	if r == 0 {
		f.Close()
		if e != nil {
			return nil, e
		}
		return nil, fmt.Errorf("无法锁定 %s", path)
	}
	return func() {
		unlock := syscall.NewLazyDLL("kernel32.dll").NewProc("UnlockFileEx")
		_, _, _ = unlock.Call(f.Fd(), 0, 1, 0, 0)
		f.Close()
	}, nil
}

func openBrowser(page string) error {
	shell32 := syscall.NewLazyDLL("shell32.dll")
	proc := shell32.NewProc("ShellExecuteW")
	verb, err := syscall.UTF16PtrFromString("open")
	if err != nil {
		return err
	}
	target, err := syscall.UTF16PtrFromString(page)
	if err != nil {
		return err
	}
	r, _, e := proc.Call(0, uintptr(unsafe.Pointer(verb)), uintptr(unsafe.Pointer(target)), 0, 0, 1)
	if r <= 32 {
		if e != nil {
			return e
		}
		return fmt.Errorf("无法打开浏览器")
	}
	return nil
}

func report(err error) {
	msg := err.Error()
	fmt.Fprintln(os.Stderr, "兀雨 vRain:", msg)
	user32 := syscall.NewLazyDLL("user32.dll")
	proc := user32.NewProc("MessageBoxW")
	title, _ := syscall.UTF16PtrFromString("兀雨 vRain")
	text, _ := syscall.UTF16PtrFromString(msg)
	const mbIconError = 0x10
	_, _, _ = proc.Call(0, uintptr(unsafe.Pointer(text)), uintptr(unsafe.Pointer(title)), mbIconError)
}

func watchSignals(cmd *exec.Cmd) {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-ch
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
	}()
}
