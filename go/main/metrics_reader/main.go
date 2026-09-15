// Command metrics-reader prints EKS CPU, memory, and pod restarts for the last hour.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1
//
// Usage:
//
//	CLUSTER_NAME=meridian-cluster AWS_DEFAULT_REGION=us-east-1 go run ./cmd/metrics-reader
//	DEBUG=1 go run ./cmd/metrics-reader   # prints SEARCH expressions + window
//
// Why it looks this way:
//   - main only reads env, builds the AWS client, and prints.
//     All CloudWatch math lives in internal/cloudwatch for testability.
//   - Every error is handled with an explicit variable (no blank identifier),
//     so failures say which metric and which AWS call broke.
//   - Queries use GetMetricData SEARCH in namespace ContainerInsights (matching
//     terraform/monitoring.tf). Real series carry full dimension sets
//     (InstanceId/NodeName or PodName/Namespace).
package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"

	internalcloudwatch "internal-tooling/internal/cloudwatch"
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
		fmt.Printf("metrics-reader failed: %v\n", mainErr)
		os.Exit(1)
	}
}

func run() error {
	clusterName := getenvOrDefault("CLUSTER_NAME", "meridian-cluster")
	region := getenvOrDefault("AWS_DEFAULT_REGION", "us-east-1")
	debugRaw := getenvOrDefault("DEBUG", "")
	debug := strings.TrimSpace(strings.ToLower(debugRaw)) == "1" ||
		strings.TrimSpace(strings.ToLower(debugRaw)) == "true"
	ctx := context.Background()
	cfg, cfgErr := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if cfgErr != nil {
		wrapped := fmt.Errorf("load AWS config (region %s): %w", region, cfgErr)
		return wrapped
	}
	client := cloudwatch.NewFromConfig(cfg)
	end := time.Now().UTC()
	start := end.Add(-1 * time.Hour)
	queries := internalcloudwatch.DefaultQueries(clusterName)
	fmt.Printf("EKS CloudWatch metrics for cluster %s (last hour, region %s)\n", clusterName, region)
	fmt.Printf("Window: %s to %s\n", start.Format(time.RFC3339), end.Format(time.RFC3339))
	emptyCount := 0
	for idx := range queries {
		query := queries[idx]
		if debug {
			expression := internalcloudwatch.BuildSearchExpression(query)
			fmt.Printf("DEBUG query %s: namespace=%s metric=%s statistic=%s expression=%s\n",
				query.Label, query.Namespace, query.MetricName, query.Statistic, expression)
		}
		result, fetchErr := internalcloudwatch.FetchMetric(ctx, client, query, start, end)
		if fetchErr != nil {
			fmt.Printf("%s: ERROR %v\n", query.Label, fetchErr)
			continue
		}
		if len(result.Points) == 0 {
			emptyCount++
		}
		line := internalcloudwatch.FormatResult(query.Label, result)
		fmt.Println(line)
	}
	if emptyCount == len(queries) {
		fmt.Println(internalcloudwatch.ObservabilityHint(clusterName, region))
	}
	return nil
}
