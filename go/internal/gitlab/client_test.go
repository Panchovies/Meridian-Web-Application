package gitlab

// Tests spin up httptest.Server fakes so no real GitLab token or network
// is needed. This avoids API rate limits and random network failures.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func strPtr(value string) *string {
	copied := value
	return &copied
}

// TestListPipelines verifies parsing of the pipelines list endpoint.
func TestListPipelines(t *testing.T) {
	pipelines := []Pipeline{
		{ID: 101, Ref: "main", Status: "success"},
		{ID: 100, Ref: "main", Status: "failed"},
	}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, req *http.Request) {
		if req.Header.Get("PRIVATE-TOKEN") != "test-token" {
			writer.WriteHeader(http.StatusUnauthorized)
			writeErr := writeTestBytes(writer, []byte(`{"message":"unauthorized"}`))
			if writeErr != nil {
				fmt.Printf("test server write failed: %v\n", writeErr)
			}
			return
		}
		if req.URL.Path != "/api/v4/projects/123/pipelines" {
			writer.WriteHeader(http.StatusNotFound)
			writeErr := writeTestBytes(writer, []byte(`{"message":"not found"}`))
			if writeErr != nil {
				fmt.Printf("test server write failed: %v\n", writeErr)
			}
			return
		}
		body, marshalErr := json.Marshal(pipelines)
		if marshalErr != nil {
			writer.WriteHeader(http.StatusInternalServerError)
			return
		}
		writer.Header().Set("Content-Type", "application/json")
		writer.WriteHeader(http.StatusOK)
		writeErr := writeTestBytes(writer, body)
		if writeErr != nil {
			fmt.Printf("test server write failed: %v\n", writeErr)
		}
	}))
	defer server.Close()
	client := NewClient(server.URL, "123", "test-token", server.Client())
	got, listErr := client.ListPipelines(10)
	if listErr != nil {
		t.Fatalf("ListPipelines returned error: %v", listErr)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 pipelines, got %d", len(got))
	}
	if got[0].ID != 101 {
		t.Fatalf("expected first ID 101, got %d", got[0].ID)
	}
	if got[1].Status != "failed" {
		t.Fatalf("expected second status failed, got %q", got[1].Status)
	}
}

// TestGetFailedStage verifies the earliest failed job stage is returned.
func TestGetFailedStage(t *testing.T) {
	jobs := []Job{
		{ID: 2, Stage: "deploy", Status: "failed"},
		{ID: 1, Stage: "build", Status: "failed"},
		{ID: 3, Stage: "test", Status: "success"},
	}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, req *http.Request) {
		body, marshalErr := json.Marshal(jobs)
		if marshalErr != nil {
			writer.WriteHeader(http.StatusInternalServerError)
			return
		}
		writer.Header().Set("Content-Type", "application/json")
		writer.WriteHeader(http.StatusOK)
		writeErr := writeTestBytes(writer, body)
		if writeErr != nil {
			fmt.Printf("test server write failed: %v\n", writeErr)
		}
	}))
	defer server.Close()
	client := NewClient(server.URL, "123", "test-token", server.Client())
	stage, stageErr := client.GetFailedStage(42)
	if stageErr != nil {
		t.Fatalf("GetFailedStage returned error: %v", stageErr)
	}
	if stage != "build" {
		t.Fatalf("expected earliest failed stage build, got %q", stage)
	}
}

// TestFormatDuration verifies duration math including in-progress pipelines.
func TestFormatDuration(t *testing.T) {
	started := strPtr("2026-09-14T10:00:00Z")
	finished := strPtr("2026-09-14T10:02:30Z")
	got := FormatDuration(started, finished)
	if got != "2m 30s" {
		t.Fatalf("expected 2m 30s, got %q", got)
	}
	inProgress := FormatDuration(started, nil)
	if inProgress != "in progress" {
		t.Fatalf("expected in progress, got %q", inProgress)
	}
	missing := FormatDuration(nil, finished)
	if missing != "N/A" {
		t.Fatalf("expected N/A, got %q", missing)
	}
}

func writeTestBytes(writer http.ResponseWriter, body []byte) error {
	written := 0
	for written < len(body) {
		count, writeErr := writer.Write(body[written:])
		if writeErr != nil {
			return writeErr
		}
		written += count
	}
	return nil
}
