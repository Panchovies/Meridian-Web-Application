package health

// Package health pings the Flask application /health endpoint.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1
// Design notes:
//   - CheckOnce does one HTTP GET and returns a Result. It has no loops or
//     sleeps, so tests can call it with an httptest.Server.
//   - Tracker counts consecutive failures and reports when an alert is due.
//   - LogResultToFile appends one line per check; main.go owns the ticker.

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// HTTPDoer matches *http.Client. Tests inject a client pointing at a fake server.
type HTTPDoer interface {
	Do(req *http.Request) (*http.Response, error)
}

// Checker performs single health checks.
type Checker struct {
	HTTPClient HTTPDoer
	Timeout    time.Duration
}

// Result is the outcome of one check.
type Result struct {
	OK         bool
	StatusCode int
	Body       string
	Duration   time.Duration
	CheckedAt  time.Time
	ErrMsg     string
}

// HealthPayload is the expected JSON shape: {"status": "ok", ...}.
type HealthPayload struct {
	Status string `json:"status"`
}

// NewChecker builds a Checker with a timeout. A nil client gets a default.
func NewChecker(httpClient HTTPDoer, timeout time.Duration) *Checker {
	if httpClient == nil {
		defaultClient := &http.Client{Timeout: timeout}
		return &Checker{HTTPClient: defaultClient, Timeout: timeout}
	}
	return &Checker{HTTPClient: httpClient, Timeout: timeout}
}

// CheckOnce GETs the URL and reports whether the app is healthy.
// Healthy means: HTTP 200 and JSON body contains status ok/ready.
func (checker *Checker) CheckOnce(targetURL string) Result {
	start := time.Now()
	checkedAt := start.UTC()
	req, reqErr := http.NewRequest(http.MethodGet, targetURL, nil)
	if reqErr != nil {
		return Result{OK: false, CheckedAt: checkedAt, Duration: time.Since(start), ErrMsg: reqErr.Error()}
	}
	resp, doErr := checker.HTTPClient.Do(req)
	if doErr != nil {
		return Result{OK: false, CheckedAt: checkedAt, Duration: time.Since(start), ErrMsg: doErr.Error()}
	}
	defer func() {
		closeErr := resp.Body.Close()
		if closeErr != nil {
			fmt.Printf("warning: closing health response body failed: %v\n", closeErr)
		}
	}()
	body, readErr := io.ReadAll(resp.Body)
	if readErr != nil {
		return Result{OK: false, StatusCode: resp.StatusCode, CheckedAt: checkedAt, Duration: time.Since(start), ErrMsg: readErr.Error()}
	}
	bodyText := string(body)
	if resp.StatusCode != http.StatusOK {
		msg := fmt.Sprintf("unexpected status %d", resp.StatusCode)
		return Result{OK: false, StatusCode: resp.StatusCode, Body: bodyText, CheckedAt: checkedAt, Duration: time.Since(start), ErrMsg: msg}
	}
	payload := HealthPayload{}
	jsonErr := json.Unmarshal(body, &payload)
	if jsonErr != nil {
		msg := fmt.Sprintf("invalid JSON: %v", jsonErr)
		return Result{OK: false, StatusCode: resp.StatusCode, Body: bodyText, CheckedAt: checkedAt, Duration: time.Since(start), ErrMsg: msg}
	}
	if payload.Status != "ok" && payload.Status != "ready" {
		msg := fmt.Sprintf("unhealthy status field: %q", payload.Status)
		return Result{OK: false, StatusCode: resp.StatusCode, Body: bodyText, CheckedAt: checkedAt, Duration: time.Since(start), ErrMsg: msg}
	}
	return Result{OK: true, StatusCode: resp.StatusCode, Body: bodyText, CheckedAt: checkedAt, Duration: time.Since(start)}
}

// Tracker counts consecutive failures and decides when to alert.
// AlertAfter3 means stdout alert after three failures in a row.
type Tracker struct {
	ConsecutiveFailures int
}

// Record updates the counter. Call it after every CheckOnce.
func (tracker *Tracker) Record(ok bool) {
	if ok {
		tracker.ConsecutiveFailures = 0
		return
	}
	tracker.ConsecutiveFailures++
}

// ShouldAlert reports true once the threshold (3) is reached.
func (tracker *Tracker) ShouldAlert() bool {
	return tracker.ConsecutiveFailures >= 3
}

// FormatLogLine renders one log file line.
func FormatLogLine(result Result) string {
	status := "FAIL"
	if result.OK {
		status = "OK"
	}
	errPart := result.ErrMsg
	if errPart == "" {
		errPart = "-"
	}
	return fmt.Sprintf(
		"%s status=%s code=%d latency_ms=%d body=%q err=%q",
		result.CheckedAt.Format(time.RFC3339),
		status,
		result.StatusCode,
		result.Duration.Milliseconds(),
		result.Body,
		errPart,
	)
}

// LogResultToFile appends one line to the log file.
func LogResultToFile(path string, result Result) error {
	file, openErr := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if openErr != nil {
		wrapped := fmt.Errorf("open log file %s: %w", path, openErr)
		return wrapped
	}
	defer func() {
		closeErr := file.Close()
		if closeErr != nil {
			fmt.Printf("warning: closing log file failed: %v\n", closeErr)
		}
	}()
	line := FormatLogLine(result) + "\n"
	writeErr := writeStringToFile(file, line)
	if writeErr != nil {
		return writeErr
	}
	return nil
}

func writeStringToFile(file *os.File, line string) error {
	bytes := []byte(line)
	written := 0
	for written < len(bytes) {
		count, writeErr := file.Write(bytes[written:])
		if writeErr != nil {
			wrapped := fmt.Errorf("write log file: %w", writeErr)
			return wrapped
		}
		written += count
	}
	return nil
}
