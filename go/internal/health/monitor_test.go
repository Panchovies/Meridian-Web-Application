package health

// Tests use httptest.Server fakes and temp log files, so no real app or
// network is needed. This keeps tests deterministic and fast.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestCheckOnceHealthy verifies a 200 ok payload is reported healthy.
func TestCheckOnceHealthy(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, req *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		writer.WriteHeader(http.StatusOK)
		body := []byte(`{"status":"ok","timestamp":"2026-09-14T00:00:00Z","message":"App is running"}`)
		written := 0
		for written < len(body) {
			count, writeErr := writer.Write(body[written:])
			if writeErr != nil {
				fmt.Printf("test server write failed: %v\n", writeErr)
				return
			}
			written += count
		}
	}))
	defer server.Close()
	checker := NewChecker(server.Client(), 5*time.Second)
	result := checker.CheckOnce(server.URL)
	if result.ErrMsg != "" {
		t.Fatalf("expected no error message, got %q", result.ErrMsg)
	}
	if result.OK != true {
		t.Fatalf("expected OK true, got false with status %d", result.StatusCode)
	}
	if result.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", result.StatusCode)
	}
}

// TestCheckOnceFailure verifies a 500 is reported unhealthy with details.
func TestCheckOnceFailure(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, req *http.Request) {
		writer.WriteHeader(http.StatusInternalServerError)
		body := []byte(`oops`)
		written := 0
		for written < len(body) {
			count, writeErr := writer.Write(body[written:])
			if writeErr != nil {
				fmt.Printf("test server write failed: %v\n", writeErr)
				return
			}
			written += count
		}
	}))
	defer server.Close()
	checker := NewChecker(server.Client(), 5*time.Second)
	result := checker.CheckOnce(server.URL)
	if result.OK != false {
		t.Fatalf("expected OK false for 500")
	}
	if result.ErrMsg == "" {
		t.Fatalf("expected error message for 500, got empty")
	}
}

// TestTrackerAlertsAfterThree verifies the alert threshold logic.
func TestTrackerAlertsAfterThree(t *testing.T) {
	tracker := &Tracker{}
	tracker.Record(false)
	if tracker.ShouldAlert() != false {
		t.Fatalf("should not alert after 1 failure")
	}
	tracker.Record(false)
	if tracker.ShouldAlert() != false {
		t.Fatalf("should not alert after 2 failures")
	}
	tracker.Record(false)
	if tracker.ShouldAlert() != true {
		t.Fatalf("should alert after 3 failures")
	}
	tracker.Record(true)
	if tracker.ShouldAlert() != false {
		t.Fatalf("success should reset consecutive failures")
	}
	if tracker.ConsecutiveFailures != 0 {
		t.Fatalf("expected counter reset to 0, got %d", tracker.ConsecutiveFailures)
	}
}

// TestLogResultToFile verifies log lines are appended with OK/FAIL markers.
func TestLogResultToFile(t *testing.T) {
	dir := t.TempDir()
	logPath := filepath.Join(dir, "health.log")
	okResult := Result{OK: true, StatusCode: 200, Body: `{"status":"ok"}`, CheckedAt: time.Now().UTC(), Duration: 5 * time.Millisecond}
	logErr := LogResultToFile(logPath, okResult)
	if logErr != nil {
		t.Fatalf("log OK result failed: %v", logErr)
	}
	failResult := Result{OK: false, StatusCode: 500, Body: "oops", CheckedAt: time.Now().UTC(), Duration: 7 * time.Millisecond, ErrMsg: "unexpected status 500"}
	logFailErr := LogResultToFile(logPath, failResult)
	if logFailErr != nil {
		t.Fatalf("log FAIL result failed: %v", logFailErr)
	}
	content, readErr := os.ReadFile(logPath)
	if readErr != nil {
		t.Fatalf("read log file failed: %v", readErr)
	}
	text := string(content)
	if strings.Contains(text, "status=OK") != true {
		t.Fatalf("expected OK line in log, got: %s", text)
	}
	if strings.Contains(text, "status=FAIL") != true {
		t.Fatalf("expected FAIL line in log, got: %s", text)
	}
}
