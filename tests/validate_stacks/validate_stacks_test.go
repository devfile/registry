package main

import (
	"flag"
	"math/rand"
	"strings"
	"testing"
	"time"

	"github.com/devfile/library/pkg/devfile"
	"github.com/devfile/library/pkg/devfile/parser"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var stacksDir string
var filesStr string

func init() {
	rand.Seed(time.Now().UnixNano())
	flag.StringVar(&stacksDir, "stacksDir", "../../stacks", "The directory containing the stacks")
	flag.StringVar(&filesStr, "filesStr", "", "The files to test as a string separated by spaces")
}

var stacks []string

func TestStacks(t *testing.T) {
	RegisterFailHandler(Fail)

	// perform work that needs to be done before the Tree Construction Phase here
	// note that we wrap `t` with a new Gomega instance to make assertions about the fixtures here.
	// more at: https://onsi.github.io/ginkgo/#dynamically-generating-specs

	if filesStr != "" {
		stacks = strings.Split(filesStr, " ")
	} else {
		// initialize the stacks array to zero
		stacks = make([]string, 0)
	}

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
