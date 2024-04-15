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

	"github.com/devfile/library/v2/pkg/devfile"
	"github.com/devfile/library/v2/pkg/devfile/parser"
	"github.com/devfile/library/v2/pkg/devfile/parser/data/v2/common"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var stacksPath string
var stackDirs string

func init() {
	rand.Seed(time.Now().UnixNano())
	flag.StringVar(&stacksPath, "stacksPath", "../../stacks", "The path to the directory containing the stacks")
	flag.StringVar(&stackDirs, "stackDirs", "", "The stacks to test as a string separated by spaces")
}

// all stacks to be tested
var stacks []Stack

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
		base := filepath.Join(stacksPath, dir)
		path := filepath.Join(base, "devfile.yaml")
		parserArgs := parser.ParserArgs{
			Path: path,
		}

		devfile, _, err := devfile.ParseDevfileAndValidate(parserArgs)
		g.Expect(err).To(BeNil())

		schemaVersion := devfile.Data.GetSchemaVersion()
		name := devfile.Data.GetMetadata().Name
		version := devfile.Data.GetMetadata().Version
		starterProjects, err := devfile.Data.GetStarterProjects(common.DevfileOptions{})
		g.Expect(err).To(BeNil())

		stack := Stack{name: name, schemaVersion: schemaVersion, version: version, path: path, starterProjects: starterProjects, base: base}

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
		stack := stack

		// TEMP: ignore testing schema versions 2.2.2 & 2.2.1 due to odo incompatibility
		// related issue: https://github.com/devfile/api/issues/1494
		if stack.schemaVersion == "2.2.1" || stack.schemaVersion == "2.2.2" {
			continue
		}

		if len(stack.starterProjects) == 0 {
			It(fmt.Sprintf("stack: %s version: %s no_starter", stack.name, stack.version), func() {
				// No starter projects defined in Devfile => let's start a Dev Session with --no-commands
				// (i.e., without implicitly executing any build and/or run commands), since there won't be any source code.
				// So here, we just want to make sure that odo dev starts properly (to cover cases for example where the dev container does not end up running).
				cmpName := fmt.Sprintf("cmp-%s-%s", stack.name, randomString(3))
				_, _, err := runOdo("init", "--devfile-path", stack.path, "--name", cmpName)
				Expect(err).To(BeNil())

				// Copy all additional resources found inside the stack directory.
				err = copyDir(stack.base, filepath.Join(tmpDir, "app"))
				Expect(err).To(BeNil())

				devStdout, devStderr, devProcess, err := runOdoDev("--no-commands")
				Expect(err).To(BeNil())

				var stopped bool
				defer func() {
					if !stopped {
						_ = devProcess.Process.Kill()
						_ = devProcess.Wait()
					}
					_, _, _ = runOdo("delete", "component", "--force")
				}()

				var stdoutContentRead []string
				Eventually(func(g Gomega) string {
					tmpBuffer := make([]byte, 4096)
					_, rErr := devStdout.Read(tmpBuffer)
					if rErr != io.EOF {
						g.Expect(rErr).ShouldNot(HaveOccurred())
					}
					stdoutReadSoFar := string(tmpBuffer)
					fmt.Fprintln(GinkgoWriter, stdoutReadSoFar)

					stdoutContentRead = append(stdoutContentRead, stdoutReadSoFar)
					return strings.Join(stdoutContentRead, "\n")
				}).WithTimeout(3*time.Minute).WithPolling(10*time.Second).Should(
					SatisfyAll(
						ContainSubstring("Keyboard Commands:"),
						// The matcher below is to prevent flakiness (case for example of a Pod with a terminating command,
						// where the pod could still run briefly but stop afterward); odo would try to sync files when it detects
						// the pod is running but not succeed to do so because the pod ended up being restarted.
						Not(ContainSubstring("failed to sync to component with name %s", cmpName)),
					),
					func() string {
						// Stopping the dev process to be able to read its stderr output without blocking
						// (devStderr is a pipe, and we can read only as long as something is writing to it).
						_ = devProcess.Process.Kill()
						_ = devProcess.Wait()
						stopped = true

						dataStderr, _ := io.ReadAll(devStderr)

						return fmt.Sprintf(`Dev Session not started properly. See logs below:
*** STDOUT ****
%s

**** STDERR ****
%s
`, strings.Join(stdoutContentRead, "\n"), string(dataStderr))
					})
			})

		} else {
			for _, starterProject := range stack.starterProjects {
				starterProject := starterProject
				It(fmt.Sprintf("stack: %s version: %s starter: %s", stack.name, stack.version, starterProject.Name), func() {

					_, _, err := runOdo("init", "--devfile-path", stack.path, "--starter", starterProject.Name, "--name", starterProject.Name)
					Expect(err).To(BeNil())

					// Copy all additional resources found inside the stack directory.
					err = copyDir(stack.base, filepath.Join(tmpDir, "app"))
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

	maxTries := 50
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
func runOdoDev(additionalArgs ...string) (io.ReadCloser, io.ReadCloser, *exec.Cmd, error) {
	args := []string{"dev", "--random-ports"}
	args = append(args, additionalArgs...)
	GinkgoWriter.Println("Executing odo " + strings.Join(args, " "))
	cmd := exec.Command("odo", args...)

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

// copyDir: Copies all items inside given stack's directory to the given destination.
// If the item exists it skips it.
func copyDir(src string, dst string) error {
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		sourceEntryPath := filepath.Join(src, entry.Name())
		destEntryPath := filepath.Join(dst, entry.Name())
		sourceEntryInfo, err := os.Stat(sourceEntryPath)
		if err != nil {
			return err
		}
		_, err = os.Stat(destEntryPath)
		// check if destination exists
		if err == nil {
			// if it exists continue
			continue
		} else if !os.IsNotExist(err) {
			// for every other err return it
			return err
		}

		// if entry is a directory, create a dir in destination and go one level down.
		if sourceEntryInfo.IsDir() {
			os.Mkdir(destEntryPath, 0755)
			err = copyDir(sourceEntryPath, destEntryPath)
			if err != nil {
				return err
			}
			continue
		}
		// if is not a dir copy file
		err = copyFile(sourceEntryPath, destEntryPath)
		if err != nil {
			return err
		}
	}
	return nil
}

// this is not the best way to copy files
func copyFile(src string, dst string) error {
	GinkgoWriter.Printf("Copying file %s to %s\n", src, dst)
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
