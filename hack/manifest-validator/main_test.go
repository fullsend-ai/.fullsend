package main

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The repo override is the shape merged in .fullsend#209. Inheriting the
// models from defaults did not make the name-plus-enabled entries valid.
const incidentManifest = `version: 1
defaults:
  inference:
    auth: vertex-wif
  config:
    agents:
      - name: code
        model: opus
      - name: triage
        model: sonnet
github:
  repos:
    - name: fullsend-ai/mlflow-assessments
      config:
        agents:
          - name: code
            enabled: true
          - name: triage
            enabled: true
`

func TestValidationExitStatus(t *testing.T) {
	fixed := strings.Replace(incidentManifest, "name: code\n            enabled", "name: code\n            model: opus\n            enabled", 1)
	fixed = strings.Replace(fixed, "name: triage\n            enabled", "name: triage\n            model: sonnet\n            enabled", 1)
	tests := []struct {
		name, manifest, diagnostic string
		want                       int
	}{
		{"pr209", incidentManifest, "enabled agent entry", 1},
		{"pr210", fixed, "Validated complete manifest: 1", 0},
		{"unknown-field", fixed + "unexpected_field: true\n", "", 1},
		{"invalid-version", strings.Replace(fixed, "version: 1", "version: 999", 1), "unsupported manifest version", 1},
		{"invalid-yaml", "version: [\n", "", 1},
		{"invalid-second-repo", fixed + "    - name: fullsend-ai/another\n      config:\n        agents:\n          - name: triage\n            enabled: true\n", "fullsend-ai/another", 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "repos.yaml")
			if err := os.WriteFile(path, []byte(tt.manifest), 0o600); err != nil {
				t.Fatal(err)
			}
			var output bytes.Buffer
			if got := run([]string{path}, &output); got != tt.want {
				t.Fatalf("exit = %d, want %d: %s", got, tt.want, output.String())
			}
			if !strings.Contains(output.String(), tt.diagnostic) {
				t.Fatalf("missing diagnostic %q: %s", tt.diagnostic, output.String())
			}
			after, err := os.ReadFile(path)
			if err != nil || string(after) != tt.manifest {
				t.Fatal("validation changed the manifest", err)
			}
		})
	}
}

func TestMissingManifestAndUsageFail(t *testing.T) {
	for _, args := range [][]string{nil, {"https://example.com/repos.yaml"}, {filepath.Join(t.TempDir(), "missing.yaml")}} {
		if got := run(args, io.Discard); got == 0 {
			t.Fatalf("unexpected success for %v", args)
		}
	}
}
