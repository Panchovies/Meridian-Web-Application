package gitlab

// Package gitlab queries the GitLab pipelines API.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1
//
// Why this shape:
//   - HTTPDoer is an interface with a single Do method. Production passes an
//     *http.Client; tests pass a fake or an httptest.Server-backed client.
//     That keeps all network calls mocked, so tests never hit API limits.
//   - Pure helpers (FormatDuration, FormatUTC) have no I/O, so they are
//     trivially testable.

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

// HTTPDoer matches *http.Client without importing it directly.
// Any type with Do(*http.Request) (*http.Response, error) satisfies it.
type HTTPDoer interface {
	Do(req *http.Request) (*http.Response, error)
}

// Client holds GitLab connection settings.
// Token is stored but never printed: see FormatPipeline which omits it.
type Client struct {
	BaseURL    string
	ProjectID  string
	Token      string
	HTTPClient HTTPDoer
}

// Pipeline is the subset of fields we print for each run.
type Pipeline struct {
	ID     int    `json:"id"`
	Ref    string `json:"ref"`
	Status string `json:"status"`
}

// PipelineDetail carries timing fields used for duration math.
type PipelineDetail struct {
	ID         int     `json:"id"`
	SHA        string  `json:"sha"`
	WebURL     string  `json:"web_url"`
	CreatedAt  string  `json:"created_at"`
	StartedAt  *string `json:"started_at"`
	FinishedAt *string `json:"finished_at"`
}

// Job is the subset of job fields needed to find failing stages.
type Job struct {
	ID     int    `json:"id"`
	Stage  string `json:"stage"`
	Status string `json:"status"`
}

// NewClient builds a Client with a 15s timeout when caller passes nil.
// The timeout mirrors scripts/ops/pipeline-summary.py REQUEST_TIMEOUT.
func NewClient(baseURL string, projectID string, token string, httpClient HTTPDoer) *Client {
	if httpClient == nil {
		timeoutClient := &http.Client{Timeout: 15 * time.Second}
		return &Client{BaseURL: baseURL, ProjectID: projectID, Token: token, HTTPClient: timeoutClient}
	}
	return &Client{BaseURL: baseURL, ProjectID: projectID, Token: token, HTTPClient: httpClient}
}

// authRequest builds a GET request with the PRIVATE-TOKEN header.
func (client *Client) authRequest(fullURL string) (*http.Request, error) {
	req, reqErr := http.NewRequest(http.MethodGet, fullURL, nil)
	if reqErr != nil {
		return nil, reqErr
	}
	req.Header.Set("PRIVATE-TOKEN", client.Token)
	return req, nil
}

// doGet executes the request, checks the status code, and closes the body.
// The body bytes are returned so callers can unmarshal them.
func (client *Client) doGet(fullURL string) ([]byte, http.Header, error) {
	req, reqErr := client.authRequest(fullURL)
	if reqErr != nil {
		return nil, nil, reqErr
	}
	resp, doErr := client.HTTPClient.Do(req)
	if doErr != nil {
		return nil, nil, doErr
	}
	defer func() {
		closeErr := resp.Body.Close()
		if closeErr != nil {
			// Body close failures are rare; we intentionally do not fail the
			// whole call for them, but we must still handle the error
			// explicitly (no blank identifier allowed).
			fmt.Printf("warning: closing response body failed: %v\n", closeErr)
		}
	}()
	body, readErr := io.ReadAll(resp.Body)
	if readErr != nil {
		return nil, nil, readErr
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		statusErr := fmt.Errorf("gitlab API %s returned status %d: %s", fullURL, resp.StatusCode, string(body))
		return nil, nil, statusErr
	}
	return body, resp.Header, nil
}

// ListPipelines fetches the most recent pipelines, newest first.
func (client *Client) ListPipelines(limit int) ([]Pipeline, error) {
	base := fmt.Sprintf("%s/api/v4/projects/%s/pipelines", client.BaseURL, client.ProjectID)
	values := url.Values{}
	values.Set("per_page", strconv.Itoa(limit))
	values.Set("order_by", "id")
	values.Set("sort", "desc")
	fullURL := base + "?" + values.Encode()
	body, headers, getErr := client.doGet(fullURL)
	if getErr != nil {
		return nil, getErr
	}
	// headers are returned for pagination use by callers; ListPipelines itself
	// does not need them, but we must reference them explicitly.
	if headers == nil {
		return nil, fmt.Errorf("missing headers in pipelines response")
	}
	pipelines := []Pipeline{}
	unmarshalErr := json.Unmarshal(body, &pipelines)
	if unmarshalErr != nil {
		return nil, unmarshalErr
	}
	return pipelines, nil
}

// GetDetail fetches one pipeline including sha, timestamps, and web_url.
func (client *Client) GetDetail(pipelineID int) (PipelineDetail, error) {
	fullURL := fmt.Sprintf("%s/api/v4/projects/%s/pipelines/%d", client.BaseURL, client.ProjectID, pipelineID)
	body, headers, getErr := client.doGet(fullURL)
	if getErr != nil {
		empty := PipelineDetail{}
		return empty, getErr
	}
	if headers == nil {
		empty := PipelineDetail{}
		return empty, fmt.Errorf("missing headers in detail response")
	}
	detail := PipelineDetail{}
	unmarshalErr := json.Unmarshal(body, &detail)
	if unmarshalErr != nil {
		empty := PipelineDetail{}
		return empty, unmarshalErr
	}
	return detail, nil
}

// GetFailedStage returns the stage of the earliest failed job.
// It paginates (100 per page) like the Python version so large pipelines
// are fully covered. Returns "None" when nothing failed.
func (client *Client) GetFailedStage(pipelineID int) (string, error) {
	failed := []Job{}
	page := 1
	for {
		base := fmt.Sprintf("%s/api/v4/projects/%s/pipelines/%d/jobs", client.BaseURL, client.ProjectID, pipelineID)
		values := url.Values{}
		values.Set("per_page", "100")
		values.Set("page", strconv.Itoa(page))
		fullURL := base + "?" + values.Encode()
		body, headers, getErr := client.doGet(fullURL)
		if getErr != nil {
			return "", getErr
		}
		jobs := []Job{}
		unmarshalErr := json.Unmarshal(body, &jobs)
		if unmarshalErr != nil {
			return "", unmarshalErr
		}
		if len(jobs) == 0 {
			break
		}
		for idx := range jobs {
			if jobs[idx].Status == "failed" {
				failed = append(failed, jobs[idx])
			}
		}
		nextPage := headers.Get("X-Next-Page")
		if nextPage == "" {
			break
		}
		parsed, parseErr := strconv.Atoi(nextPage)
		if parseErr != nil {
			return "", parseErr
		}
		page = parsed
	}
	if len(failed) == 0 {
		return "None", nil
	}
	earliest := failed[0]
	for idx := range failed {
		if failed[idx].ID < earliest.ID {
			earliest = failed[idx]
		}
	}
	if earliest.Stage == "" {
		return "Unknown", nil
	}
	return earliest.Stage, nil
}

// FormatDuration mirrors the Python fmt_duration helper:
// "Xm Ys", "in progress" when unfinished, "N/A" when unparseable.
func FormatDuration(startedAt *string, finishedAt *string) string {
	if startedAt == nil || *startedAt == "" {
		return "N/A"
	}
	if finishedAt == nil || *finishedAt == "" {
		return "in progress"
	}
	start, startErr := time.Parse(time.RFC3339, *startedAt)
	if startErr != nil {
		return "N/A"
	}
	finish, finishErr := time.Parse(time.RFC3339, *finishedAt)
	if finishErr != nil {
		return "N/A"
	}
	seconds := int(finish.Sub(start).Seconds())
	if seconds < 0 {
		return "N/A"
	}
	minutes := seconds / 60
	rem := seconds % 60
	return fmt.Sprintf("%dm %ds", minutes, rem)
}

// FormatUTC renders an ISO-8601 timestamp as "YYYY-MM-DD HH:MM:SS UTC".
func FormatUTC(iso *string) string {
	if iso == nil || *iso == "" {
		return "N/A"
	}
	parsed, parseErr := time.Parse(time.RFC3339, *iso)
	if parseErr != nil {
		return *iso
	}
	utc := parsed.UTC()
	return utc.Format("2006-01-02 15:04:05 UTC")
}

// FormatPipeline renders one pipeline block for stdout.
func FormatPipeline(pipeline Pipeline, detail PipelineDetail, failedStage string) string {
	duration := FormatDuration(detail.StartedAt, detail.FinishedAt)
	created := FormatUTC(stringPtrToRef(detail.CreatedAt))
	started := FormatUTC(detail.StartedAt)
	out := fmt.Sprintf(
		"Pipeline:       #%d\nRef:            %s\nCommit SHA:     %s\nStatus:         %s\nCreated:        %s\nStarted:        %s\nDuration:       %s\nFailed stage:   %s\nURL:            %s\n---------------------------------------------------------------------------",
		pipeline.ID,
		pipeline.Ref,
		detail.SHA,
		pipeline.Status,
		created,
		started,
		duration,
		failedStage,
		detail.WebURL,
	)
	return out
}

func stringPtrToRef(value string) *string {
	// Small helper so FormatUTC (which takes *string) can accept plain strings
	// without the caller using a blank identifier or inline address tricks.
	copied := value
	return &copied
}
