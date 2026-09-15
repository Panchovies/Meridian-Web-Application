// Command health-monitor pings the Flask application /health endpoint every 30 seconds.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1
// Usage:
//
//	HEALTH_URL=http://localhost:8000/health LOG_FILE=health.log go run ./main/health_monitor
//
//	Replace HEALTH_URL with the URL of your service's health endpoint
//
// Behavior:
//   - GETs HEALTH_URL every INTERVAL (default 30s).
//   - Appends timestamped result to LOG_FILE.
//   - Prints ALERT to stdout after three consecutive failures.
//   - Healthy means HTTP 200 with JSON {"status": "ok"} (or "ready").
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"internal-tooling/internal/health"
)

func getenvOrDefault(key string, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func parseInterval(raw string, fallback time.Duration) (time.Duration, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return fallback, nil
	}
	seconds, parseErr := strconv.Atoi(trimmed)
	if parseErr != nil {
		// Accept Go durations like "30s" as well as plain seconds.
		duration, durationErr := time.ParseDuration(trimmed)
		if durationErr != nil {
			combined := fmt.Errorf("invalid interval %q: %w", raw, parseErr)
			return fallback, combined
		}
		return duration, nil
	}
	return time.Duration(seconds) * time.Second, nil
}

func main() {
	mainErr := run()
	if mainErr != nil {
		fmt.Printf("health-monitor failed: %v\n", mainErr)
		os.Exit(1)
	}
}

func run() error {
	targetURL := getenvOrDefault("HEALTH_URL", "http://localhost:8000/health")
	logFile := getenvOrDefault("LOG_FILE", "health.log")
	intervalRaw := getenvOrDefault("INTERVAL_SECONDS", "30")
	interval, intervalErr := parseInterval(intervalRaw, 30*time.Second)
	if intervalErr != nil {
		return intervalErr
	}
	timeout := 10 * time.Second
	checker := health.NewChecker(nil, timeout)
	tracker := &health.Tracker{}
	fmt.Printf("health-monitor: pinging %s every %s, logging to %s\n", targetURL, interval.String(), logFile)
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	// One immediate check before waiting for the first tick, so users see
	// output right away instead of staring at silence for 30s.
	initialErr := checkAndRecord(checker, tracker, targetURL, logFile)
	if initialErr != nil {
		return initialErr
	}
	for tick := range ticker.C {
		fmt.Printf("tick %s: checking %s\n", tick.UTC().Format(time.RFC3339), targetURL)
		tickErr := checkAndRecord(checker, tracker, targetURL, logFile)
		if tickErr != nil {
			return tickErr
		}
	}
	return nil
}

func checkAndRecord(checker *health.Checker, tracker *health.Tracker, targetURL string, logFile string) error {
	result := checker.CheckOnce(targetURL)
	tracker.Record(result.OK)
	logErr := health.LogResultToFile(logFile, result)
	if logErr != nil {
		wrapped := fmt.Errorf("log result: %w", logErr)
		return wrapped
	}
	if result.OK {
		fmt.Printf("OK %s code=%d latency=%s\n", targetURL, result.StatusCode, result.Duration.String())
		return nil
	}
	fmt.Printf("FAIL %s err=%s failures=%d\n", targetURL, result.ErrMsg, tracker.ConsecutiveFailures)
	if tracker.ShouldAlert() {
		fmt.Printf("ALERT: %s failed %d times in a row (last error: %s)\n", targetURL, tracker.ConsecutiveFailures, result.ErrMsg)
	}
	return nil
}
