package main

import (
	"fmt"
	"os"

	devfilePkg "github.com/devfile/library/v2/pkg/devfile"
	"github.com/devfile/library/v2/pkg/devfile/parser"
)

func main() {
	devfilePath := os.Args[1]
	flattenDevfile := true

	parserArgs := parser.ParserArgs{
		Path:             devfilePath,
		FlattenedDevfile: &flattenDevfile,
	}

	// flatten parent of given devfile path
	devfile, _, err := devfilePkg.ParseDevfileAndValidate(parserArgs)

	if err != nil {
		fmt.Printf("error while parsing devfile:: %s", err)
		os.Exit(1)
	}
	// write-update flattened devfile
	err = devfile.WriteYamlDevfile()
	if err != nil {
		fmt.Printf("error while writing devfile:: %s", err)
		os.Exit(1)
	}
}
