package main

import (
	"flag"
	"math/rand"
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
var filesStr string

func init() {
	rand.Seed(time.Now().UnixNano())
	flag.StringVar(&stacksDir, "stacksDir", "../../stacks", "The directory containing the stacks")
	flag.StringVar(&filesStr, "filesStr", "", "The files to test as a string separated by spaces")
}

var stacks []string

func TestStacks(t *testing.T) {
	RegisterFailHandler(Fail)

	stacks = strings.Split(string(filesStr), " ")

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
