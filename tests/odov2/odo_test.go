/*
run 5 test in paralel:
ginkgo run --procs 5

specifying flags:
ginkgo run -v  -- -stacksPath <path>

test only one stack with a specific stack id:
ginkgo run --focus "stack: java-vertx starter: vertx-http-example"  -- -stacksPath ../../stacks

test all starter project in a specific stack:
ginkgo run --focus "stack: java-vertx"  -- -stacksPath ../../stacks
*/

package main

import (
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/devfile/library/pkg/devfile"
	"github.com/devfile/library/pkg/devfile/parser"
	"github.com/devfile/library/pkg/devfile/parser/data/v2/common"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var (
	stacksPath string
	stackDirs  string
	env        string
	registry   string
	semverRe   = regexp.MustCompile(`^(\d+)\.(\d+)\.(\d+)$`)

	// all stacks to be tested
	stacks []Stack
)

func init() {
	rand.Seed(time.Now().UnixNano())
	flag.StringVar(&stacksPath, "stacksPath", "../../stacks", "The path to the directory containing the stacks")
	flag.StringVar(&stackDirs, "stackDirs", "", "The stacks to test as a string separated by spaces")
	flag.StringVar(&env, "env", "minikube", "The environment to run the tests in")
	flag.StringVar(&registry, "registry", "local", "The registry to use for the tests")

	if !(env == "minikube" || env == "openshift") {
		fmt.Println("env must be either minikube or openshift")
		os.Exit(1)
	}

	if !(registry == "local" || registry == "remote") {
		fmt.Println("registry must be either local or remote")
		os.Exit(1)
	}
}

func TestOdo(t *testing.T) {
	RegisterFailHandler(Fail)

	// perform work that needs to be done before the Tree Construction Phase here
	// note that we wrap `t` with a new Gomega instance to make assertions about the fixtures here.
	// more at: https://onsi.github.io/ginkgo/#dynamically-generating-specs
	g := NewGomegaWithT(t)

	var dirs []string

	if stackDirs != "" {
		dirs = strings.Split(stackDirs, " ")
	}

	for _, dir := range dirs {
		path := filepath.Join(stacksPath, dir, "devfile.yaml")

		parserArgs := parser.ParserArgs{
			Path: path,
		}

		devfile, _, err := devfile.ParseDevfileAndValidate(parserArgs)
		g.Expect(err).To(BeNil())

		name := devfile.Data.GetMetadata().Name
		version := devfile.Data.GetMetadata().Version
		schemaVersion := devfile.Data.GetSchemaVersion()
		starterProjects, err := devfile.Data.GetStarterProjects(common.DevfileOptions{})
		g.Expect(err).To(BeNil())

		components, err := devfile.Data.GetComponents(common.DevfileOptions{})
		g.Expect(err).To(BeNil())

		ports := []int{}
		for _, component := range components {
			if component.Container != nil {
				for _, endpoint := range component.Container.Endpoints {
					if endpoint.Exposure == "none" || endpoint.Exposure == "internal" {
						continue
					}
					ports = append(ports, endpoint.TargetPort)
				}
			}
		}

		stack := Stack{name: name, version: version, schemaVersion: schemaVersion, starterProjects: starterProjects, ports: ports, path: path}

		stacks = append(stacks, stack)
	}

	GinkgoWriter.Println("Total stacks found", len(stacks), "stacks")

	RunSpecs(t, "odo suite")
}

var _ = Describe("test starter projects from devfile stacks", func() {

	var namespace string
	var tmpDir string
	var oldDir string
	var oldKubeConfig string

	var _ = BeforeEach(func() {
		// save current working directory and make sure that we go back
		var err error
		oldDir, err = os.Getwd()
		Expect(err).To(BeNil())

		// create new temporary directory and change to it
		tmpDir, err = os.MkdirTemp("", "")
		Expect(err).To(BeNil())

		// use copy of KUBECONFIG to make sure that we don't change the original one
		oldKubeConfig = os.Getenv("KUBECONFIG")
		tmpKubeConfig := filepath.Join(tmpDir, "kubeconfig")
		if oldKubeConfig == "" {
			home, err := os.UserHomeDir()
			Expect(err).To(BeNil())
			copyFile(filepath.Join(home, ".kube", "config"), tmpKubeConfig)
		} else {
			copyFile(oldKubeConfig, tmpKubeConfig)
		}
		os.Setenv("KUBECONFIG", tmpKubeConfig)

		GinkgoWriter.Printf("KUBECONFIG=%s\n", os.Getenv("KUBECONFIG"))

		// use dedicated odo preference file for tests
		os.Setenv("GLOBALODOCONFIG", filepath.Join(tmpDir, "preference.yaml"))

		// disable telemetry
		_, _, err = runOdo("preference", "set", "ConsentTelemetry", "false")
		Expect(err).To(BeNil())

		// use Ephemeral (emptyDir) volumes instead of PVC
		_, _, err = runOdo("preference", "set", "ephemeral", "true")
		Expect(err).To(BeNil())

		// create new directory for the application and set it as the current working directory
		appDir := filepath.Join(tmpDir, "app")
		os.Mkdir(appDir, 0755)
		os.Chdir(appDir)

		namespace = randomString(8)
		_, _, err = runOdo("project", "create", namespace)
		Expect(err).To(BeNil())

		GinkgoWriter.Println("Using namespace:", namespace)
	})

	var _ = AfterEach(func() {
		// delete the namespace
		_, _, err := runOdo("delete", "-f", "-a")
		Expect(err).To(BeNil())

		_, _, err = runOdo("project", "delete", "-f", namespace)
		Expect(err).To(BeNil())

		os.Setenv("KUBECONFIG", oldKubeConfig)
		os.Chdir(oldDir)
		os.RemoveAll(tmpDir)
	})

	for _, stack := range stacks {
		for _, starterProject := range stack.starterProjects {
			stack := stack
			starterProject := starterProject

			major, minor, _, err := getSemverVersion(stack.version)
			Expect(err).To(BeNil())

			// Skip stacks that are not supported by odo v2
			if major > 2 || (major == 2 && minor >= 2) {
				continue
			}

			It(fmt.Sprintf("stack: %s version: %s starter: %s", stack.name, stack.version, starterProject.Name), func() {
				if registry == "local" {
					_, _, err = runOdo("create", "--devfile", stack.path, "--starter", starterProject.Name)
				} else {
					_, _, err = runOdo("create", stack.name, "--starter", starterProject.Name)
				}
				Expect(err).To(BeNil())

				if env == "minikube" {
					for _, port := range stack.ports {
						GinkgoWriter.Printf("Creating url: $(minikube ip).nip.io:%s", strconv.Itoa(port))
						_, _, err = runOdo("url", "create", "--host", "$(minikube ip).nip.io", "--port", strconv.Itoa(port))
						Expect(err).To(BeNil())
					}
				}

				_, _, err = runOdo("push")
				Expect(err).To(BeNil())

				urls, err := getUrls()
				Expect(err).To(BeNil())

				for _, url := range urls {
					err = waitForHttp(url, 200)
					Expect(err).To(BeNil())
				}
			})
		}
	}

})

// run odo commands
// returns stdout, stderr, and error
func runOdo(args ...string) ([]byte, []byte, error) {
	GinkgoWriter.Println("Executing: odo", strings.Join(args, " "))
	cmd := exec.Command("odo", args...)

	stdOutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, nil, err
	}

	stdErrPipe, err := cmd.StderrPipe()
	if err != nil {
		return nil, nil, err
	}

	err = cmd.Start()
	if err != nil {
		return nil, nil, err
	}

	stdOut, err := io.ReadAll(stdOutPipe)
	if err != nil {
		return nil, nil, err
	}

	stdErr, err := io.ReadAll(stdErrPipe)
	if err != nil {
		return nil, nil, err
	}

	err = cmd.Wait()
	if err != nil {
		return nil, nil, err
	}

	return stdOut, stdErr, nil
}

// get urls from the output of `odo url list`
func getUrls() ([]string, error) {
	// Cannot use the runOdo function because we need to prepend "bash -c" to the command
	args := []string{"-c", "odo", "url", "list", "|", "awk", "'{ print $3 }'", "|", "tail", "-n", "+3", "|", "tr", "'\\n'", "' '"}
	GinkgoWriter.Println("Executing: odo", strings.Join(append([]string{"bash"}, args...), " "))
	stdOut, err := exec.Command("bash", args...).Output()
	if err != nil {
		return nil, err
	}

	urls := strings.Split(strings.TrimSpace(string(stdOut)), " ")

	PrintIfNotEmpty("URLs found:", strings.Join(urls, " "))

	return urls, nil
}

func waitForHttp(url string, expectedCode int) error {
	maxTries := 12
	delay := 10 * time.Second
	for i := 0; i < maxTries; i++ {
		GinkgoWriter.Printf("Waiting for %s to return %d. Try %d of %d\n", url, expectedCode, i+1, maxTries)
		client := &http.Client{}
		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			GinkgoWriter.Printf("Unable to create HTTP Request %s. Trying again in %f\n", err, delay.Seconds())
			time.Sleep(delay)
			continue
		}
		req.Header.Set("Accept", "*/*")
		resp, err := client.Do(req)
		if err != nil {
			GinkgoWriter.Printf("Unable to get %s. Trying again in %f\n", err, delay.Seconds())
			time.Sleep(delay)
			continue
		}
		defer resp.Body.Close()
		if resp.StatusCode == expectedCode {
			GinkgoWriter.Printf("%s returned %d\n", url, expectedCode)
			return nil
		}
		GinkgoWriter.Printf("Unexpected return code %d. Trying again in %s\n", resp.StatusCode, delay)
		time.Sleep(delay)
	}

	// try to retrieve logs to see what happened
	stdOut, stdErr, err := runOdo("logs")
	if err != nil {
		GinkgoWriter.Printf("Unable to get odo logs: %s\n", err)
	}
	GinkgoWriter.Printf("odo logs stdout: %s\n", stdOut)
	GinkgoWriter.Printf("odo logs stderr: %s\n", stdErr)
	return fmt.Errorf("%s did not return %d", url, expectedCode)
}

const letters = "abcdefghijklmnopqrstuvwxyz"

func randomString(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}

// this is not the best way to copy files
func copyFile(src string, dst string) error {
	input, err := os.ReadFile(src)
	if err != nil {
		return err
	}

	err = os.WriteFile(dst, input, 0644)
	if err != nil {
		return err
	}
	return nil
}

func getSemverVersion(version string) (int, int, int, error) {
	matches := semverRe.FindStringSubmatch(version)
	if len(matches) != 4 {
		return 0, 0, 0, fmt.Errorf("error occurred while parsing semver version %s", version)
	}

	major, err := strconv.Atoi(matches[1])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("error occurred while parsing major version %s", version)
	}

	minor, err := strconv.Atoi(matches[2])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("error occurred while parsing minor version %s", version)
	}

	patch, err := strconv.Atoi(matches[3])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("error occurred while parsing patch version %s", version)
	}

	return major, minor, patch, nil
}

// write to GinkgoWriter if str is not empty.
// format will be "description str"
func PrintIfNotEmpty(description string, str string) {
	if str != "" {
		GinkgoWriter.Printf("%s %s\n", description, str)
	}
}
