package rhtap

import (
	"flag"
	"math/rand"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	appservice "github.com/redhat-appstudio/application-api/api/v1alpha1"
	"github.com/redhat-appstudio/e2e-tests/pkg/clients/has"
	e2eKube "github.com/redhat-appstudio/e2e-tests/pkg/clients/kubernetes"
	"github.com/redhat-appstudio/e2e-tests/pkg/framework"
	testHub "github.com/redhat-appstudio/e2e-tests/pkg/framework"
	"github.com/redhat-appstudio/e2e-tests/pkg/utils"
)

var samplesFile string
var namespace string

const pipelineCompletionRetries = 2

func init() {
	rand.Seed(time.Now().UnixNano())
	flag.StringVar(&samplesFile, "samplesFile", "../../extraDevfileEntries.yaml", "Parent stack file")
	flag.StringVar(&namespace, "namespace", "", "Namespace where create and build stack samples")
}

func TestRhtap(t *testing.T) {
	RegisterFailHandler(Fail)

	RunSpecs(t, "rhtap suite")

}

var _ = Describe("RHTAP sample checks", Ordered, Label("nightly"), func() {
	var fw *testHub.ControllerHub
	component := &appservice.Component{}
	cdq := &appservice.ComponentDetectionQuery{}

	entries, err := LoadExtraDevfileEntries(samplesFile)
	Expect(err).NotTo(HaveOccurred())

	for _, sampleEntry := range entries.Samples {
		testNamespace := namespace
		sampleEntry := sampleEntry

		Describe(sampleEntry.Name, func() {
			var kubeadminClient *framework.ControllerHub

			BeforeAll(func() {
				kubeClient, err := e2eKube.NewAdminKubernetesClient()
				Expect(err).NotTo(HaveOccurred())
				fw, err = testHub.InitControllerHub(kubeClient)
				Expect(err).NotTo(HaveOccurred())

				// If not namespace specified creates one
				if testNamespace == "" {
					ns, err := fw.CommonController.CreateTestNamespace(utils.GetGeneratedNamespace("stack"))
					Expect(err).NotTo(HaveOccurred())
					testNamespace = ns.Name
				}
			})

			AfterAll(func() {
				if !CurrentSpecReport().Failed() {
					if err := fw.HasController.DeleteAllComponentsInASpecificNamespace(testNamespace, 60*time.Second); err != nil {
						GinkgoWriter.Printf("error deleting all componentns in namespace:\n%s", err)
					}
					if err := fw.HasController.DeleteAllApplicationsInASpecificNamespace(testNamespace, 60*time.Second); err != nil {
						GinkgoWriter.Printf("error deleting all componentns in namespace:\n%s", err)
					}
				}
			})

			// Create an application in a specific namespace
			It("creates an application", func() {
				GinkgoWriter.Printf("Parallel process %d\n", GinkgoParallelProcess())
				createdApplication, err := fw.HasController.CreateApplication(sampleEntry.Name, testNamespace)
				Expect(err).NotTo(HaveOccurred())
				Expect(createdApplication.Namespace).To(Equal(testNamespace))
			})

			// Check the application health and check if a devfile was generated in the status
			It("checks if application is healthy", func() {
				Eventually(func() string {
					application, err := fw.HasController.GetApplication(sampleEntry.Name, testNamespace)
					Expect(err).NotTo(HaveOccurred())

					return application.Status.Devfile
				}, 3*time.Minute, 100*time.Millisecond).Should(Not(BeEmpty()), "Error creating gitOps repository")
			})

			It("creates componentdetectionquery", func() {
				for _, sampleEntryVersion := range sampleEntry.Versions {
					if sampleEntryVersion.Default {
						sampleEntryGit := sampleEntryVersion.Git.Remotes.Origin
						cdq, err = fw.HasController.CreateComponentDetectionQuery(sampleEntry.Name, testNamespace, sampleEntryGit, "", "", "", false)
						Expect(err).NotTo(HaveOccurred())
						break
					}
				}
			})

			It("creates component", func() {
				for _, compDetected := range cdq.Status.ComponentDetected {
					component, err = fw.HasController.CreateComponent(compDetected.ComponentStub, testNamespace, "", "", sampleEntry.Name, true, map[string]string{})
					Expect(err).NotTo(HaveOccurred())
				}
			})

			// Start to watch the pipeline until is finished
			It("waits component pipeline to be finished", func() {
				component, err = fw.HasController.GetComponent(component.Name, testNamespace)
				Expect(err).ShouldNot(HaveOccurred(), "failed to get component: %v", err)

				Expect(fw.HasController.WaitForComponentPipelineToBeFinished(component, "",
					kubeadminClient.TektonController, &has.RetryOptions{Retries: pipelineCompletionRetries, Always: true})).To(Succeed())
			})
		})
	}
})
