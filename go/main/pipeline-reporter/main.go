// Command pipeline-reporter prints status, duration, and failing stages
// for the last 10 GitLab pipeline runs.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1
//
// Usage:
//
//	GITLAB_URL=https://gitlab.com GITLAB_PROJECT_ID=123 GITLAB_TOKEN=xxx go run ./main/pipeline-reporter
//
// It ports scripts/ops/pipeline-summary.py (5 pipelines) to Go with limit 10.
// The token is read from the environment and never printed.
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"internal-tooling/internal/gitlab"
)

func getenvOrDefault(key string, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func main() {
	mainErr := run()
	if mainErr != nil {
		fmt.Printf("pipeline-reporter failed: %v\n", mainErr)
		os.Exit(1)
	}
}

func run() error {
	baseURL := getenvOrDefault("GITLAB_URL", "https://gitlab.com")
	projectID := os.Getenv("GITLAB_PROJECT_ID")
	token := os.Getenv("GITLAB_TOKEN")
	missing := []string{}
	if strings.TrimSpace(projectID) == "" {
		missing = append(missing, "GITLAB_PROJECT_ID")
	}
	if strings.TrimSpace(token) == "" {
		missing = append(missing, "GITLAB_TOKEN")
	}
	if len(missing) > 0 {
		for idx := range missing {
			fmt.Printf("ERROR: %s is not set.\n", missing[idx])
		}
		return fmt.Errorf("missing required environment variables")
	}
	limit := 10
	limitRaw := os.Getenv("PIPELINE_LIMIT")
	if strings.TrimSpace(limitRaw) != "" {
		parsed, parseErr := strconv.Atoi(strings.TrimSpace(limitRaw))
		if parseErr != nil {
			return fmt.Errorf("invalid PIPELINE_LIMIT %q: %w", limitRaw, parseErr)
		}
		if parsed > 0 {
			limit = parsed
		}
	}
	client := gitlab.NewClient(baseURL, projectID, token, nil)
	pipelines, listErr := client.ListPipelines(limit)
	if listErr != nil {
		wrapped := fmt.Errorf("list pipelines: %w", listErr)
		return wrapped
	}
	fmt.Println("===========================================================================")
	fmt.Println("                    GITLAB PIPELINE SUMMARY (last 10)")
	fmt.Println("===========================================================================")
	fmt.Printf("Project ID : %s\n", projectID)
	fmt.Printf("GitLab URL : %s\n", baseURL)
	fmt.Println()
	if len(pipelines) == 0 {
		fmt.Println("No pipelines found.")
		fmt.Println("===========================================================================")
		return nil
	}
	for idx := range pipelines {
		pipeline := pipelines[idx]
		detail, detailErr := client.GetDetail(pipeline.ID)
		if detailErr != nil {
			fmt.Printf("Pipeline:       #%d\n", pipeline.ID)
			fmt.Printf("  WARNING: Could not fetch detail: %v\n", detailErr)
			fmt.Println("---------------------------------------------------------------------------")
			continue
		}
		failedStage := "N/A"
		if strings.ToUpper(strings.TrimSpace(pipeline.Status)) == "FAILED" {
			stage, stageErr := client.GetFailedStage(pipeline.ID)
			if stageErr != nil {
				failedStage = fmt.Sprintf("error retrieving: %v", stageErr)
			} else {
				failedStage = stage
			}
		}
		block := gitlab.FormatPipeline(pipeline, detail, failedStage)
		fmt.Println(block)
	}
	fmt.Println("===========================================================================")
	return nil
}
