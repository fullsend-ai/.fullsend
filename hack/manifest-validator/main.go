// This command is built inside the pinned Fullsend checkout so it can use
// the installer's internal manifest loader without duplicating its rules.
package main

import (
	"context"
	"fmt"
	"io"
	"os"

	"github.com/fullsend-ai/fullsend/internal/repos"
)

func run(args []string, output io.Writer) int {
	if len(args) != 1 {
		fmt.Fprintln(output, "usage: validate-manifest MANIFEST")
		return 2
	}
	info, err := os.Stat(args[0])
	if err == nil && !info.Mode().IsRegular() {
		err = fmt.Errorf("manifest must be a local regular file")
	}
	if err != nil {
		fmt.Fprintln(output, err)
		return 1
	}
	manifest, err := repos.LoadManifest(context.Background(), args[0])
	if err == nil {
		err = manifest.Validate()
	}
	if err != nil {
		fmt.Fprintf(output, "manifest validation failed: %v\n", err)
		return 1
	}
	fmt.Fprintf(output, "Validated complete manifest: %d repository entries\n", manifest.TotalRepoCount())
	return 0
}

func main() {
	os.Exit(run(os.Args[1:], os.Stdout))
}
