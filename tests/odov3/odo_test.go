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
var filesStr string

func init() {
	rand.Seed(time.Now().UnixNano())
	flag.StringVar(&stacksDir, "stacksDir", "../../stacks", "The directory containing the stacks")
	flag.StringVar(&filesStr, "files", "", "The files to test as a string separated by spaces")
}

// all stacks to be tested
var stacks []Stack

func TestOdo(t *testing.T) {
	RegisterFailHandler(Fail)

	// perform work that needs to be done before the Tree Construction Phase here
	// note that we wrap `t` with a new Gomega instance to make assertions about the fixtures here.
	// more at: https://onsi.github.io/ginkgo/#dynamically-generating-specs
	g := NewGomegaWithT(t)

	files := strings.Split(string(filesStr), " ")

	for _, file := range files {
		stack := Stack{id: file, devfilePath: stacksDir + "/" + file + "/devfile.yaml"}

		parserArgs := parser.ParserArgs{
			Path: stack.devfilePath,
		}

		devfile, _, err := devfile.ParseDevfileAndValidate(parserArgs)
		g.Expect(err).To(BeNil())

		stack.starterProjects, err = devfile.Data.GetStarterProjects(common.DevfileOptions{})
		g.Expect(err).To(BeNil())

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

				devStdout, devStderr, devProcess, err := runOdoDev()
				Expect(err).To(BeNil())

				// if odo dev command failed send error to this chanel to interrupt waitForPort()
				devError := make(chan error)
				go func() {
					dataStdout, err := io.ReadAll(devStdout)
					Expect(err).To(BeNil())

					dataStderr, err := io.ReadAll(devStderr)
					Expect(err).To(BeNil())

					err = devProcess.Wait()

					PrintIfNotEmpty("'odo dev' stdout:", string(dataStdout))
					PrintIfNotEmpty("'odo dev' stderr:", string(dataStderr))

					devError <- err
				}()

				ports, err := waitForPort(devError)
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
		if err != nil {
			GinkgoWriter.Printf("Unable to create %s. Trying again in %f\n", err, delay.Seconds())
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
	logsStdout, logsStderr, logsErr := runOdo("logs")
	if logsErr != nil {
		GinkgoWriter.Printf("Unable to get odo logs: %s\n", logsErr)
	}
	GinkgoWriter.Printf("odo logs stdout: %s\n", logsStdout)
	GinkgoWriter.Printf("odo logs stderr: %s\n", logsStderr)
	return fmt.Errorf("%s did not return %d", url, expectedCode)
}

// uses `odo describe component` to get the forwarded ports of the component
// returns list of forwarded ports
func waitForPort(devError chan error) ([]ForwardedPort, error) {
	args := []string{"describe", "component", "-o", "json"}

	maxTries := 20
	delay := 10 * time.Second

	stdout := []byte{}
	stderr := []byte{}
	var lastError error
	for i := 0; i < maxTries; i++ {

		// check if odo dev command failed, if yes stop and return error
		select {
		case err := <-devError:
			GinkgoWriter.Printf("'odo dev' failed with %q\n", err)
			return nil, fmt.Errorf("'odo dev' failed with %q", err)
		default:
		}

		GinkgoWriter.Println("Waiting for odo to setup port-forwarding. Try", i+1, "of", maxTries)

		var component Component
		var err error

		stdout, stderr, err = runOdo(args...)
		if err != nil {
			GinkgoWriter.Println("odo command failed")
			PrintIfNotEmpty("stdout:", string(stdout))
			PrintIfNotEmpty("stderr:", string(stderr))
			return nil, err
		}

		err = json.Unmarshal(stdout, &component)
		if err != nil {
			lastError = err
			time.Sleep(delay)
			continue
		}

		// get list ports that we should wait for
		// this ignores ports that have exposure set to "none" or "internal"
		ports := []int{}
		for _, component := range component.DevfileData.Devfile.Components {
			if component.Container != nil {
				for _, endpoint := range component.Container.Endpoints {
					if endpoint.Exposure == "none" || endpoint.Exposure == "internal" {
						continue
					}
					ports = append(ports, endpoint.TargetPort)
				}
			}
		}

		GinkgoWriter.Printf("Checking if following %v ports have port-forwarding setup.\n", ports)

		if len(component.DevForwardedPorts) >= len(ports) {
			GinkgoWriter.Println("Found ports", component.DevForwardedPorts)

			out := []ForwardedPort{}
			// return only ports that we were waiting for
			for _, forwardedPort := range component.DevForwardedPorts {
				for _, port := range ports {
					if forwardedPort.ContainerPort == port {
						out = append(out, forwardedPort)
					}
				}
			}

			return out, nil
		}
		delay += 10 * time.Second
		time.Sleep(delay)

	}

	GinkgoWriter.Println("No ports found")
	GinkgoWriter.Printf("Last error: %v", lastError)
	PrintIfNotEmpty("Last stdout:", string(stdout))
	PrintIfNotEmpty("Last stderr:", string(stderr))

	// try to retrieve logs to see what happened
	logsStdout, logsStderr, logsErr := runOdo("logs")
	if logsErr != nil {
		GinkgoWriter.Printf("Unable to get odo logs: %s\n", logsErr)
	}
	PrintIfNotEmpty("odo logs stdout:", string(logsStdout))
	PrintIfNotEmpty("odo logs stderr:", string(logsStderr))

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

	dataStdout, err := io.ReadAll(stdout)
	if err != nil {
		return nil, nil, err
	}

	dataStderr, err := io.ReadAll(stderr)
	if err != nil {
		return nil, nil, err
	}

	err = cmd.Wait()

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

// write to GinkgoWeiter if str is not empty.
// format will be "decription str"
func PrintIfNotEmpty(description string, str string) {
	if str != "" {
		GinkgoWriter.Printf("%s %s\n", description, str)
	}
}
