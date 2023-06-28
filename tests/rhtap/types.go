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

type Samples struct {
	Name        string `yaml:"name"`
	DisplayName string `yaml:"displayName"`
	Language    string `yaml:"language"`
	ProjectType string `yaml:"projectType"`
	Git         Git    `yaml:"git"`
}

type Stacks struct {
	SchemaVersion string    `yaml:"schemaVersion"`
	Samples       []Samples `yaml:"samples"`
}

func LoadTestGeneratorConfig(configPath string) (Stacks, error) {
	s := Stacks{}
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
