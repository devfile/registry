package main

import (
	"flag"
	"math/rand"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/devfile/library/pkg/devfile"
	_ "github.com/devfile/library/pkg/devfile"
	"github.com/devfile/library/pkg/devfile/parser"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var stacksDir string

func init() {
	rand.Seed(time.Now().UnixNano())
	flag.StringVar(&stacksDir, "stacksDir", "../../stacks", "The directory containing the stacks")
}

var stacks []string

func TestStacks(t *testing.T) {
	RegisterFailHandler(Fail)

	// perform work that needs to be done before the Tree Construction Phase here
	// note that we wrap `t` with a new Gomega instance to make assertions about the fixtures here.
	// more at: https://onsi.github.io/ginkgo/#dynamically-generating-specs
	g := NewGomegaWithT(t)

	cmd := exec.Command("bash", "../get_changed_stacks.sh")

	stdout, err := cmd.Output()
	g.Expect(err).To(BeNil())

	stacks = strings.Split(string(stdout), " ")

	GinkgoWriter.Println("Total stacks found:", len(stacks))
	GinkgoWriter.Println("Stacks to be tested:", stacks)

	RunSpecs(t, "Devfile Test Suite")
}

var _ = Describe("validate stacks follow the schema", func() {
	for _, stack := range stacks {
		It("validates stack schema for "+stack, func() {
			parserArgs := parser.ParserArgs{
				Path: stacksDir + "/" + stack,
			}

			GinkgoWriter.Println(parserArgs)

			_, _, err := devfile.ParseDevfileAndValidate(parserArgs)

			Expect(err).To(BeNil())
		})
	}
})
