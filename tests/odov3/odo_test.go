/*


run 5 test in paralel:
ginkgo run --procs 5

specifying flags:
ginkgo run -v  -- -stacksDir <path>

test only one stack with a specific stack id:
ginkgo run --focus "stack: java-vertx starter: vertx-http-example"  -- -stacksDir ../../stacks

test all starter project in a specific stack:
ginkgo run --focus "stack: java-vertx"  -- -stacksDir ../../stacks




*/

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/devfile/library/pkg/devfile"
	"github.com/devfile/library/pkg/devfile/parser"
	"github.com/devfile/library/pkg/devfile/parser/data/v2/common"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var stacksDir string

func init() {
	rand.Seed(time.Now().UnixNano())
	flag.StringVar(&stacksDir, "stacksDir", "../../stacks", "The directory containing the stacks")

}

// all stacks to be tested
var stacks []Stack

func TestOdo(t *testing.T) {
	RegisterFailHandler(Fail)

	// perform work that needs to be done before the Tree Construction Phase here
	// note that we wrap `t` with a new Gomega instance to make assertions about the fixtures here.
	// more at: https://onsi.github.io/ginkgo/#dynamically-generating-specs
	g := NewGomegaWithT(t)

	// make stacks path absolute, it is required because later we are using it from the random directory.
	stacksDir, err := filepath.Abs(stacksDir)
	g.Expect(err).To(BeNil())

	files, err := ioutil.ReadDir(stacksDir)
	g.Expect(err).To(BeNil())

	for _, file := range files {
		if file.IsDir() {
			stack := Stack{id: file.Name(), devfilePath: stacksDir + "/" + file.Name() + "/devfile.yaml"}

			parserArgs := parser.ParserArgs{
				Path: stack.devfilePath,
			}

			devfile, _, err := devfile.ParseDevfileAndValidate(parserArgs)
			g.Expect(err).To(BeNil())

			stack.starterProjects, err = devfile.Data.GetStarterProjects(common.DevfileOptions{})
			g.Expect(err).To(BeNil())

			stacks = append(stacks, stack)

		}
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
		_, _, err = runOdo("create", "namespace", namespace)
		Expect(err).To(BeNil())

		GinkgoWriter.Println("Using namespace:", namespace)
	})

	var _ = AfterEach(func() {
		runOdo("delete", "namespace", "-f", namespace)

		os.Setenv("KUBECONFIG", oldKubeConfig)
		os.Chdir(oldDir)
		os.RemoveAll(tmpDir)
	})

	for _, stack := range stacks {
		for _, starterProject := range stack.starterProjects {
			stack := stack
			starterProject := starterProject
			It(fmt.Sprintf("stack: %s starter: %s", stack.id, starterProject.Name), func() {

				_, _, err := runOdo("init", "--devfile-path", stack.devfilePath, "--starter", starterProject.Name, "--name", starterProject.Name)
				Expect(err).To(BeNil())

				_, _, devProcess, err := runOdoDev()
				Expect(err).To(BeNil())

				ports, err := waitForPort()
				Expect(err).To(BeNil())

				for _, port := range ports {
					err := waitForHttp(fmt.Sprintf("http://%s:%d", port.LocalAddress, port.LocalPort), 200)
					Expect(err).To(BeNil())
				}
				devProcess.Process.Kill()

				runOdo("delete", "component", "--force")
			})

		}
	}

})

func waitForHttp(url string, expectedCode int) error {
	maxTries := 12
	delay := 10 * time.Second
	for i := 0; i < maxTries; i++ {
		GinkgoWriter.Printf("Waiting for %s to return %d. Try %d of %d\n", url, expectedCode, i+1, maxTries)
		client := &http.Client{}
		req, err := http.NewRequest("GET", url, nil)
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
	return fmt.Errorf("%s did not return %d", url, expectedCode)
}

// uses `odo describe component` to get the forwarded ports of the component
// returns list of forwarded ports
func waitForPort() ([]ForwardedPort, error) {
	args := []string{"describe", "component", "-o", "json"}

	maxTries := 30
	delay := 10 * time.Second

	stdout := []byte{}
	stderr := []byte{}
	var lastError error
	for i := 0; i < maxTries; i++ {
		GinkgoWriter.Println("Waiting for odo to setup port-forwarding. Try", i+1, "of", maxTries)

		var component Component
		var err error

		stdout, stderr, err = runOdo(args...)
		if err != nil {
			GinkgoWriter.Println("odo command failed")
			GinkgoWriter.Printf("stdout: %s\n", stdout)
			GinkgoWriter.Printf("stderr: %s\n", stderr)
			return nil, err
		}

		err = json.Unmarshal(stdout, &component)
		if err != nil {
			lastError = err
			time.Sleep(delay)
			continue
		}

		if len(component.DevForwardedPorts) > 0 {
			GinkgoWriter.Println("Found ports", component.DevForwardedPorts)
			return component.DevForwardedPorts, nil
		}
		delay += 10 * time.Second
		time.Sleep(delay)

	}

	GinkgoWriter.Println("No ports found")
	GinkgoWriter.Printf("Last error: %v", lastError)
	GinkgoWriter.Printf("Last stdout: %s\n", stdout)
	GinkgoWriter.Printf("Last stderr: %s\n", stderr)
	return nil, fmt.Errorf("No ports found")

}

// run `odo dev` on the background
// returned cmd can be used to kill the process
// returns stdout pipe, stderr pipe, cmd
func runOdoDev() (io.ReadCloser, io.ReadCloser, *exec.Cmd, error) {
	GinkgoWriter.Println("Executing: odo dev")
	cmd := exec.Command("odo", "dev")

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, nil, nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, nil, nil, err
	}

	if err := cmd.Start(); err != nil {
		return nil, nil, nil, err
	}

	return stdout, stderr, cmd, nil

}

// run odo commands
// returns stdout, stderr, and error
func runOdo(args ...string) ([]byte, []byte, error) {
	GinkgoWriter.Println("Executing: odo", strings.Join(args, " "))
	cmd := exec.Command("odo", args...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, nil, err
	}

	if err := cmd.Start(); err != nil {
		return nil, nil, err
	}

	dataStdout, err := ioutil.ReadAll(stdout)
	if err != nil {
		return nil, nil, err
	}

	dataStderr, err := ioutil.ReadAll(stderr)
	if err != nil {
		return nil, nil, err
	}

	err = cmd.Wait()

	GinkgoWriter.Println("stdout:", string(dataStdout))
	GinkgoWriter.Println("stderr:", string(dataStderr))

	if err != nil {
		return nil, nil, err
	}

	return dataStdout, dataStderr, nil

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
	input, err := ioutil.ReadFile(src)
	if err != nil {
		return err
	}

	err = ioutil.WriteFile(dst, input, 0644)
	if err != nil {
		return err
	}
	return nil
}
