package main

import (
	"fmt"
	"os"

	"vrain.dev/launcher/bundle"
)

func main() {
	if len(os.Args) != 4 {
		fmt.Fprintln(os.Stderr, "usage: pack <launcher|-> <stage-dir> <output>")
		os.Exit(2)
	}
	launcher := os.Args[1]
	if launcher == "-" {
		launcher = ""
	}
	if err := bundle.Pack(launcher, os.Args[2], os.Args[3]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
