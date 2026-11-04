package main

import (
	"bufio"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"vrain.dev/launcher/bundle"
)

func main() {
	if err := run(); err != nil {
		report(err)
		os.Exit(1)
	}
}

func run() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	payload, err := bundle.Locate(exe)
	if err != nil {
		return err
	}
	sum, err := bundle.Hash(payload)
	if err != nil {
		return err
	}
	hexSum := hex.EncodeToString(sum)
	root := cacheRoot()
	if err := os.MkdirAll(root, 0o755); err != nil {
		return err
	}
	logf := openLog(filepath.Join(root, "launcher.log"))
	if logf != nil {
		defer logf.Close()
	}

	if live := liveURL(root, hexSum); live != "" {
		mirror(logf, "VRAIN_READY "+live)
		return maybeBrowse(live)
	}

	unlock, err := acquire(filepath.Join(root, "launch.lock"))
	if err != nil {
		return err
	}
	held := true
	defer func() {
		if held {
			unlock()
		}
	}()

	if live := liveURL(root, hexSum); live != "" {
		unlock()
		held = false
		mirror(logf, "VRAIN_READY "+live)
		return maybeBrowse(live)
	}

	dest := filepath.Join(root, hexSum)
	if _, err := os.Stat(filepath.Join(dest, ".complete")); err != nil {
		mirror(logf, "解压运行环境")
	}
	if err := bundle.Extract(payload, dest); err != nil {
		return err
	}
	prune(root, hexSum)

	cmd, stdout, stderr, err := startServer(dest)
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return err
	}
	ready := make(chan string, 1)
	go scanReady(stdout, logf, ready)
	go copyLines(stderr, logf)
	exited := make(chan error, 1)
	go func() { exited <- cmd.Wait() }()
	watchSignals(cmd)

	page, err := waitReady(cmd, ready, exited, 90*time.Second)
	if err != nil {
		return err
	}
	_ = os.WriteFile(filepath.Join(root, "current.hash"), []byte(hexSum+"\n"), 0o644)
	_ = os.WriteFile(filepath.Join(root, "current.url"), []byte(page+"\n"), 0o644)
	unlock()
	held = false

	if err := maybeBrowse(page); err != nil {
		report(fmt.Errorf("页面已启动，但没有打开浏览器。请手动打开 %s", page))
	}
	err = <-exited
	if err != nil && !strings.Contains(err.Error(), "signal:") {
		return fmt.Errorf("服务已退出：%v", err)
	}
	return nil
}

func cacheRoot() string {
	if v := strings.TrimSpace(os.Getenv("VRAIN_CACHE_DIR")); v != "" {
		return v
	}
	switch runtime.GOOS {
	case "windows":
		base := os.Getenv("LOCALAPPDATA")
		if base == "" {
			base = filepath.Join(os.Getenv("USERPROFILE"), "AppData", "Local")
		}
		return filepath.Join(base, "vRain", "runtime")
	case "darwin":
		home, _ := os.UserHomeDir()
		return filepath.Join(home, "Library", "Caches", "vRain")
	default:
		if v := strings.TrimSpace(os.Getenv("XDG_CACHE_HOME")); v != "" {
			return filepath.Join(v, "vrain-web")
		}
		home, _ := os.UserHomeDir()
		return filepath.Join(home, ".cache", "vrain-web")
	}
}

func liveURL(root, hexSum string) string {
	b, err := os.ReadFile(filepath.Join(root, "current.hash"))
	if err != nil || strings.TrimSpace(string(b)) != hexSum {
		return ""
	}
	raw, err := os.ReadFile(filepath.Join(root, "current.url"))
	if err != nil {
		return ""
	}
	page := strings.TrimSpace(string(raw))
	if !healthOK(page) {
		return ""
	}
	return page
}

func healthOK(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil {
		return false
	}
	host := u.Hostname()
	if host != "127.0.0.1" && host != "localhost" && host != "::1" {
		return false
	}
	client := &http.Client{Timeout: 800 * time.Millisecond}
	resp, err := client.Get(strings.TrimRight(raw, "/") + "/api/health")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)
	return resp.StatusCode == 200
}

func maybeBrowse(page string) error {
	if strings.TrimSpace(os.Getenv("VRAIN_NO_BROWSER")) != "" {
		return nil
	}
	return openBrowser(page)
}

func startServer(root string) (*exec.Cmd, io.Reader, io.Reader, error) {
	perl, prefixes, err := findPerl(root)
	if err != nil {
		return nil, nil, nil, err
	}
	cmd := exec.Command(perl, filepath.Join(root, "web", "server.pl"))
	cmd.Dir = root
	env := os.Environ()
	env = append(env, "VRAIN_NO_BROWSER=1")
	if len(prefixes) > 0 {
		env = prependPath(env, prefixes)
	}
	lib := filepath.Join(root, "runtime", "lib")
	if st, err := os.Stat(lib); err == nil && st.IsDir() {
		env = prependEnv(env, "LD_LIBRARY_PATH", lib)
		env = prependEnv(env, "DYLD_LIBRARY_PATH", lib)
	}
	cmd.Env = env
	configure(cmd)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, nil, nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, nil, nil, err
	}
	return cmd, stdout, stderr, nil
}

func findPerl(root string) (string, []string, error) {
	unix := filepath.Join(root, "runtime", "perl", "bin", "perl")
	if st, err := os.Stat(unix); err == nil && !st.IsDir() {
		if runtime.GOOS != "windows" {
			_ = os.Chmod(unix, 0o755)
		}
		return unix, nil, nil
	}
	win := filepath.Join(root, "runtime", "strawberry", "perl", "bin", "perl.exe")
	if st, err := os.Stat(win); err == nil && !st.IsDir() {
		return win, []string{
			filepath.Join(root, "runtime", "strawberry", "perl", "bin"),
			filepath.Join(root, "runtime", "strawberry", "c", "bin"),
		}, nil
	}
	return "", nil, errors.New("没有找到附带的 Perl")
}

func scanReady(r io.Reader, logf *os.File, ready chan<- string) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), 2*1024*1024)
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r")
		mirror(logf, line)
		const mark = "VRAIN_READY "
		if i := strings.Index(line, mark); i >= 0 {
			page := strings.TrimSpace(line[i+len(mark):])
			if page != "" {
				select {
				case ready <- page:
				default:
				}
			}
		}
	}
}

func copyLines(r io.Reader, logf *os.File) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), 2*1024*1024)
	for sc.Scan() {
		mirror(logf, strings.TrimRight(sc.Text(), "\r"))
	}
}

func waitReady(cmd *exec.Cmd, ready <-chan string, exited <-chan error, timeout time.Duration) (string, error) {
	timer := time.NewTimer(timeout)
	defer timer.Stop()
	select {
	case page := <-ready:
		return page, nil
	case err := <-exited:
		select {
		case page := <-ready:
			return page, nil
		case <-time.After(300 * time.Millisecond):
		}
		if err != nil {
			return "", fmt.Errorf("服务启动失败：%v", err)
		}
		return "", errors.New("服务启动失败")
	case <-timer.C:
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		<-exited
		return "", errors.New("服务没有在时限内就绪")
	}
}

func mirror(logf *os.File, line string) {
	fmt.Fprintln(os.Stdout, line)
	if logf != nil {
		fmt.Fprintln(logf, line)
	}
}

func openLog(path string) *os.File {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return nil
	}
	return f
}

func prune(root, keep string) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, e := range entries {
		name := e.Name()
		if !e.IsDir() || name == keep || len(name) != 64 || !isHex(name) {
			continue
		}
		os.RemoveAll(filepath.Join(root, name))
	}
}

func isHex(s string) bool {
	for _, c := range s {
		switch {
		case c >= '0' && c <= '9':
		case c >= 'a' && c <= 'f':
		default:
			return false
		}
	}
	return true
}

func prependEnv(env []string, key, value string) []string {
	prefix := key + "="
	for i, item := range env {
		if strings.HasPrefix(item, prefix) {
			rest := strings.TrimPrefix(item, prefix)
			if rest == "" {
				env[i] = prefix + value
			} else {
				env[i] = prefix + value + string(os.PathListSeparator) + rest
			}
			return env
		}
	}
	return append(env, prefix+value)
}

func prependPath(env []string, dirs []string) []string {
	extra := strings.Join(dirs, string(os.PathListSeparator))
	return prependEnv(env, "PATH", extra)
}
