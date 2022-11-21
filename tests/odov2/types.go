package main

import (
	"github.com/devfile/api/v2/pkg/apis/workspaces/v1alpha2"
)

type Stack struct {
	name            string
	version         string
	schemaVersion   string
	starterProjects []v1alpha2.StarterProject
	ports           []int
	path            string
}
