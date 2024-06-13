package main

import (
	"flag"
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/devfile/library/v2/pkg/devfile"
	"github.com/devfile/library/v2/pkg/devfile/parser"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var stacksPath string
var stackDirs string

func init() {
	flag.StringVar(&stacksPath, "stacksPath", "../../stacks", "The path to the directory containing the stacks")
	flag.StringVar(&stackDirs, "stackDirs", "", "The stacks to test as a string separated by spaces")
}

var dirs []string

func TestStacks(t *testing.T) {
	RegisterFailHandler(Fail)

	// perform work that needs to be done before the Tree Construction Phase here
	// note that we wrap `t` with a new Gomega instance to make assertions about the fixtures here.
	// more at: https://onsi.github.io/ginkgo/#dynamically-generating-specs

	GinkgoWriter.Println("test", stackDirs)

	if stackDirs != "" {
		dirs = strings.Split(stackDirs, " ")
	}

	GinkgoWriter.Println("Total stacks found:", len(dirs))
	GinkgoWriter.Println("Stacks to be tested:", dirs)

	RunSpecs(t, "Devfile Test Suite")
}

var _ = Describe("validate stacks follow the schema", func() {
	for _, dir := range dirs {
		It(fmt.Sprintf("stack: %s", dir), func() {
			path := filepath.Join(stacksPath, dir, "devfile.yaml")

			parserArgs := parser.ParserArgs{
				Path: path,
			}

			GinkgoWriter.Println(parserArgs)

			_, _, err := devfile.ParseDevfileAndValidate(parserArgs)

			Expect(err).To(BeNil())
		})
	}
})
