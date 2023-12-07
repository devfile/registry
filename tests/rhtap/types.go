package rhtap

import (
	"os"
	"path/filepath"

	"gopkg.in/yaml.v2"
)

type Remotes struct {
	Origin string `yaml:"origin"`
}

type Git struct {
	Remotes Remotes `yaml:"remotes"`
}

type Version struct {
	Default bool `yaml:"default"`
	Git     Git  `yaml:"git"`
}

type SampleEntry struct {
	Name        string    `yaml:"name"`
	DisplayName string    `yaml:"displayName"`
	Language    string    `yaml:"language"`
	ProjectType string    `yaml:"projectType"`
	Versions    []Version `yaml:"versions"`
}

type ExtraDevfileEntries struct {
	SchemaVersion string        `yaml:"schemaVersion"`
	Samples       []SampleEntry `yaml:"samples"`
}

func LoadExtraDevfileEntries(configPath string) (ExtraDevfileEntries, error) {
	s := ExtraDevfileEntries{}
	// Open config file
	file, err := os.Open(filepath.Clean(configPath))
	if err != nil {
		return s, err
	}

	// Init new YAML decode
	d := yaml.NewDecoder(file)

	// Start YAML decoding from file
	if err := d.Decode(&s); err != nil {
		return s, err
	}

	return s, nil
}
