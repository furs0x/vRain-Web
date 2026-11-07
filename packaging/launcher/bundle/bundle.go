// Package bundle packs and reads the zstd-tar payload carried by a vRain binary.
package bundle

import (
	"archive/tar"
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/klauspost/compress/zstd"
)

const (
	Magic     = "VRAINPKG"
	FooterLen = 56
)

// Pack copies launcher (unless it is empty) and appends a zstd tar of dir.
// An empty launcher writes a standalone payload file whose footer offset is 0.
func Pack(launcher, dir, out string) error {
	if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil && filepath.Dir(out) != "." {
		return err
	}
	partial := out + ".partial"
	f, err := os.OpenFile(partial, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
	if err != nil {
		return err
	}
	defer func() {
		f.Close()
		os.Remove(partial)
	}()

	var payloadStart int64
	if launcher != "" {
		in, err := os.Open(launcher)
		if err != nil {
			return err
		}
		if _, err := io.Copy(f, in); err != nil {
			in.Close()
			return err
		}
		in.Close()
		payloadStart, err = f.Seek(0, io.SeekCurrent)
		if err != nil {
			return err
		}
	}

	sum := sha256.New()
	enc, err := zstd.NewWriter(io.MultiWriter(f, sum), zstd.WithEncoderLevel(zstd.SpeedBestCompression))
	if err != nil {
		return err
	}
	if err := writeTar(enc, dir); err != nil {
		enc.Close()
		return err
	}
	if err := enc.Close(); err != nil {
		return err
	}
	payloadEnd, err := f.Seek(0, io.SeekCurrent)
	if err != nil {
		return err
	}
	footer := make([]byte, FooterLen)
	copy(footer[:8], Magic)
	binary.LittleEndian.PutUint64(footer[8:16], uint64(payloadStart))
	binary.LittleEndian.PutUint64(footer[16:24], uint64(payloadEnd-payloadStart))
	copy(footer[24:56], sum.Sum(nil))
	if _, err := f.Write(footer); err != nil {
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	if err := os.Remove(out); err != nil && !os.IsNotExist(err) {
		return err
	}
	if err := os.Rename(partial, out); err != nil {
		return err
	}
	if err := os.Chmod(out, 0o755); err != nil && !os.IsPermission(err) {
		return err
	}
	return Verify(out)
}

// Locate finds a payload attached to exe, or in a macOS app resource next to it.
func Locate(exe string) (string, error) {
	res := filepath.Clean(filepath.Join(filepath.Dir(exe), "..", "Resources", "payload.bin"))
	if _, err := describe(res); err == nil {
		return res, nil
	}
	if _, err := describe(exe); err == nil {
		return exe, nil
	}
	return "", errors.New("找不到内置的运行数据")
}

// Hash returns the payload sha256 recorded in the footer.
func Hash(path string) ([]byte, error) {
	info, err := describe(path)
	if err != nil {
		return nil, err
	}
	return info.sum, nil
}

// Extract unpacks the payload into dest. A finished dest is left in place.
func Extract(path, dest string) error {
	if complete(dest) {
		return nil
	}
	info, err := describe(path)
	if err != nil {
		return err
	}
	tmp := dest + ".tmp"
	os.RemoveAll(tmp)
	if err := os.MkdirAll(tmp, 0o755); err != nil {
		return err
	}
	f, err := os.Open(path)
	if err != nil {
		os.RemoveAll(tmp)
		return err
	}
	defer f.Close()
	sum := sha256.New()
	dec, err := zstd.NewReader(io.TeeReader(io.NewSectionReader(f, info.off, info.size), sum))
	if err != nil {
		os.RemoveAll(tmp)
		return err
	}
	err = untar(dec, tmp)
	dec.Close()
	if err != nil {
		os.RemoveAll(tmp)
		return err
	}
	if !bytes.Equal(sum.Sum(nil), info.sum) {
		os.RemoveAll(tmp)
		return errors.New("运行数据校验失败")
	}
	if err := os.WriteFile(filepath.Join(tmp, ".complete"), []byte("ok\n"), 0o644); err != nil {
		os.RemoveAll(tmp)
		return err
	}
	os.RemoveAll(dest)
	if err := os.Rename(tmp, dest); err != nil {
		os.RemoveAll(tmp)
		return err
	}
	return nil
}

// Verify checks that the compressed payload matches the footer hash.
func Verify(path string) error {
	info, err := describe(path)
	if err != nil {
		return err
	}
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	sum := sha256.New()
	if _, err := io.Copy(sum, io.NewSectionReader(f, info.off, info.size)); err != nil {
		return err
	}
	if !bytes.Equal(sum.Sum(nil), info.sum) {
		return errors.New("运行数据校验失败")
	}
	return nil
}

type footer struct {
	off  int64
	size int64
	at   int64
	sum  []byte
}

func describe(path string) (footer, error) {
	f, err := os.Open(path)
	if err != nil {
		return footer{}, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return footer{}, err
	}
	fileSize := st.Size()
	if fileSize < FooterLen {
		return footer{}, errors.New("文件太小")
	}
	window := int64(2 << 20)
	if window > fileSize {
		window = fileSize
	}
	buf := make([]byte, window)
	start := fileSize - window
	if _, err := f.ReadAt(buf, start); err != nil && err != io.EOF {
		return footer{}, err
	}
	for len(buf) >= FooterLen {
		idx := bytes.LastIndex(buf, []byte(Magic))
		if idx < 0 {
			break
		}
		at := start + int64(idx)
		if at+FooterLen <= fileSize && idx+FooterLen <= len(buf) {
			raw := buf[idx : idx+FooterLen]
			off := int64(binary.LittleEndian.Uint64(raw[8:16]))
			size := int64(binary.LittleEndian.Uint64(raw[16:24]))
			if off >= 0 && size > 32 && off+size == at {
				sum := append([]byte(nil), raw[24:56]...)
				return footer{off: off, size: size, at: at, sum: sum}, nil
			}
		}
		buf = buf[:idx]
	}
	return footer{}, errors.New("找不到内置的运行数据")
}

func complete(dest string) bool {
	st, err := os.Stat(filepath.Join(dest, ".complete"))
	if err != nil || st.IsDir() {
		return false
	}
	st, err = os.Stat(filepath.Join(dest, "web", "server.pl"))
	return err == nil && !st.IsDir()
}

func writeTar(w io.Writer, dir string) error {
	tw := tar.NewWriter(w)
	err := filepath.Walk(dir, func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		rel, err := filepath.Rel(dir, path)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if rel == "." {
			return nil
		}
		if skip(rel) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		var link string
		if info.Mode()&os.ModeSymlink != 0 {
			link, err = os.Readlink(path)
			if err != nil {
				return err
			}
		}
		hdr, err := tar.FileInfoHeader(info, link)
		if err != nil {
			return err
		}
		hdr.Name = rel
		hdr.Format = tar.FormatPAX
		if err := tw.WriteHeader(hdr); err != nil {
			return err
		}
		if info.Mode().IsRegular() {
			in, err := os.Open(path)
			if err != nil {
				return err
			}
			_, err = io.Copy(tw, in)
			in.Close()
			if err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		tw.Close()
		return err
	}
	return tw.Close()
}

func skip(rel string) bool {
	base := rel
	if i := strings.LastIndex(rel, "/"); i >= 0 {
		base = rel[i+1:]
	}
	if base == ".DS_Store" || base == ".complete" || strings.HasSuffix(base, ".tmp") {
		return true
	}
	if strings.HasSuffix(rel, ".pdf") {
		return true
	}
	if rel == "web/jobs" || strings.HasPrefix(rel, "web/jobs/") {
		return true
	}
	if strings.HasPrefix(rel, "canvas/") && strings.HasSuffix(rel, ".pl") {
		return true
	}
	return false
}

func untar(r io.Reader, dest string) error {
	tr := tar.NewReader(r)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		target, err := safeJoin(dest, hdr.Name)
		if err != nil {
			return err
		}
		switch hdr.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
		case tar.TypeReg, tar.TypeRegA:
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return err
			}
			mode := os.FileMode(hdr.Mode) & 0o777
			if mode == 0 {
				mode = 0o644
			}
			out, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
			if err != nil {
				return err
			}
			_, err = io.Copy(out, tr)
			closeErr := out.Close()
			if err != nil {
				return err
			}
			if closeErr != nil {
				return closeErr
			}
		case tar.TypeSymlink:
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return err
			}
			os.Remove(target)
			if err := os.Symlink(hdr.Linkname, target); err != nil {
				return err
			}
		default:
			return fmt.Errorf("不支持的打包类型 %s", hdr.Name)
		}
	}
}

func safeJoin(dest, name string) (string, error) {
	name = strings.TrimPrefix(name, "./")
	clean := filepath.Clean(name)
	if clean == "." {
		return dest, nil
	}
	if filepath.IsAbs(name) || clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("不安全的路径 %s", name)
	}
	full := filepath.Join(dest, clean)
	rel, err := filepath.Rel(dest, full)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("不安全的路径 %s", name)
	}
	return full, nil
}
