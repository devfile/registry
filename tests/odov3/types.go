package main

import (
	"github.com/devfile/api/v2/pkg/apis/workspaces/v1alpha2"
)

// struct for parsing `odo describe component -o json` output
// struct  from github.com/redhat-developer/odo/pkg/api/  can't be reused because DevfileData.Devfile there is an interface and not struct
type Component struct {
	DevfilePath       string          `json:"devfilePath,omitempty"`
	DevfileData       *DevfileData    `json:"devfileData,omitempty"`
	DevForwardedPorts []ForwardedPort `json:"devForwardedPorts,omitempty"`
	RunningIn         RunningModes    `json:"runningIn"`
	ManagedBy         string          `json:"managedBy"`
}
type DevfileData struct {
	Devfile              v1alpha2.Devfile      `json:"devfile"`
	SupportedOdoFeatures *SupportedOdoFeatures `json:"supportedOdoFeatures,omitempty"`
}
type SupportedOdoFeatures struct {
	Dev    bool `json:"dev"`
	Deploy bool `json:"deploy"`
	Debug  bool `json:"debug"`
}
type ForwardedPort struct {
	ContainerName string `json:"containerName"`
	LocalAddress  string `json:"localAddress"`
	LocalPort     int    `json:"localPort"`
	ContainerPort int    `json:"containerPort"`
}

type Stack struct {
	name            string
	version         string
	path            string
	starterProjects []v1alpha2.StarterProject
}

type RunningMode string
type RunningModes map[RunningMode]bool
