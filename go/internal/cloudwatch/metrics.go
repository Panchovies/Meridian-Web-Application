package cloudwatch

// Package cloudwatch reads EKS-related CloudWatch metrics for the last hour.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1
//
// Why this package exists:
//   - The main.go in cmd/metrics-reader only parses env vars and prints.
//     All AWS logic lives here so it can be unit tested with a fake client.
//   - The CloudWatchAPI interface lets tests inject canned responses instead
//     of calling AWS, so tests never hit network limits.
//
// Why GetMetricData with SEARCH:
//   - ContainerInsights publishes one series per node/pod with full dimension
//     sets, e.g. (InstanceId, NodeName, ClusterName) for node_cpu_utilization
//     and (PodName, FullPodName, ClusterName, Namespace) for restarts.
//   - GetMetricStatistics requires the exact dimension set, so a query with
//     only ClusterName always returns zero datapoints.
//   - GetMetricData SEARCH aggregates across all matching series without
//     knowing InstanceIds or PodNames in advance.
//   - Live data lives in namespace "ContainerInsights" (no AWS prefix).
//     "AWS/ContainerInsights" is empty and always returns no datapoints.

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch/types"
)

// CloudWatchAPI is the small subset of the AWS SDK we use.
// Defining our own interface (instead of using the SDK client directly)
// is what makes mocking possible: tests provide a fake implementation.
type CloudWatchAPI interface {
	GetMetricData(
		ctx context.Context,
		params *cloudwatch.GetMetricDataInput,
		optFns ...func(*cloudwatch.Options),
	) (*cloudwatch.GetMetricDataOutput, error)
}

// MetricPoint is one aggregated datapoint, kept as plain floats.
type MetricPoint struct {
	Timestamp   time.Time
	Average     float64
	Maximum     float64
	Sum         float64
	SampleCount float64
}

// MetricResult is the fetched series plus a small summary.
type MetricResult struct {
	Namespace string
	Name      string
	Points    []MetricPoint
}

// AverageOfAverages returns the mean of the Average field across points.
// It returns 0 when there are no points, so callers never divide by zero.
func (result MetricResult) AverageOfAverages() float64 {
	if len(result.Points) == 0 {
		return 0
	}
	total := 0.0
	for idx := range result.Points {
		total += result.Points[idx].Average
	}
	return total / float64(len(result.Points))
}

// SumOfSums returns the total of the Sum field across points.
// This is used for pod restarts, which are a counter, not a percentage.
func (result MetricResult) SumOfSums() float64 {
	total := 0.0
	for idx := range result.Points {
		total += result.Points[idx].Sum
	}
	return total
}

// MaxOfMaximums returns the largest Maximum value seen.
func (result MetricResult) MaxOfMaximums() float64 {
	maxVal := 0.0
	for idx := range result.Points {
		pointMax := result.Points[idx].Maximum
		if pointMax > maxVal {
			maxVal = pointMax
		}
	}
	return maxVal
}

// MetricQuery describes one metric to fetch.
type MetricQuery struct {
	Namespace   string
	MetricName  string
	ClusterName string
	// Statistic is "Average" for percentages (CPU/memory) or "Sum" for
	// counters (pod restarts).
	Statistic string
	// Label is a human friendly name used in output, e.g. "EKS CPU utilization".
	Label string
}

// DefaultQueries returns the three queries this tool always runs:
// CPU utilization, memory utilization, and pod restarts.
// They use namespace "ContainerInsights" (matching terraform/monitoring.tf
// alarms HighPodCpuOverLimit and HighContainerRestarts), scoped by
// ClusterName via a SEARCH expression so per-node/per-pod series aggregate
// without knowing InstanceIds in advance.
func DefaultQueries(clusterName string) []MetricQuery {
	queries := []MetricQuery{
		{
			Namespace:   "ContainerInsights",
			MetricName:  "node_cpu_utilization",
			ClusterName: clusterName,
			Statistic:   "Average",
			Label:       "EKS CPU utilization",
		},
		{
			Namespace:   "ContainerInsights",
			MetricName:  "node_memory_utilization",
			ClusterName: clusterName,
			Statistic:   "Average",
			Label:       "EKS memory utilization",
		},
		{
			Namespace:   "ContainerInsights",
			MetricName:  "pod_number_of_container_restarts",
			ClusterName: clusterName,
			Statistic:   "Sum",
			Label:       "Pod restarts",
		},
	}
	return queries
}

// BuildSearchExpression renders the CloudWatch SEARCH expression for a query.
// The schema {Namespace,ClusterName} intentionally lists only the dimensions
// to match on: SEARCH returns series with additional dimensions aggregated,
// unlike GetMetricStatistics which requires the exact set.
// The ClusterName filter is required: without it SEARCH returns every cluster
// in the region, so a typo in the cluster name would still show datapoints.
// Example: SEARCH('{ContainerInsights,ClusterName} MetricName="node_cpu_utilization" AND ClusterName="meridian-cluster"', 'Average', 300)
func BuildSearchExpression(query MetricQuery) string {
	return fmt.Sprintf(
		"SEARCH('{ %s,ClusterName } MetricName=\"%s\" AND ClusterName=\"%s\"', '%s', 300)",
		query.Namespace,
		query.MetricName,
		query.ClusterName,
		query.Statistic,
	)
}

// FetchMetric reads one metric for the [start, end] window via GetMetricData.
// It follows NextToken pagination so long windows are fully collected.
func FetchMetric(
	ctx context.Context,
	client CloudWatchAPI,
	query MetricQuery,
	start time.Time,
	end time.Time,
) (MetricResult, error) {
	expression := BuildSearchExpression(query)
	queryID := "q1"
	period := int32(300)
	input := &cloudwatch.GetMetricDataInput{
		StartTime: &start,
		EndTime:   &end,
		MetricDataQueries: []types.MetricDataQuery{
			{
				Id:         &queryID,
				Expression: &expression,
				Period:     &period,
			},
		},
	}
	points := []MetricPoint{}
	nextToken := ""
	firstPage := true
	for firstPage || nextToken != "" {
		firstPage = false
		if nextToken != "" {
			tokenCopy := nextToken
			input.NextToken = &tokenCopy
		} else {
			input.NextToken = nil
		}
		output, fetchErr := client.GetMetricData(ctx, input)
		if fetchErr != nil {
			empty := MetricResult{Namespace: query.Namespace, Name: query.MetricName}
			wrapped := fmt.Errorf("get metric %s/%s: %w", query.Namespace, query.MetricName, fetchErr)
			return empty, wrapped
		}
		for resultIdx := range output.MetricDataResults {
			mdResult := output.MetricDataResults[resultIdx]
			count := len(mdResult.Timestamps)
			for pointIdx := 0; pointIdx < count; pointIdx++ {
				timestamp := time.Time{}
				if pointIdx < len(mdResult.Timestamps) {
					timestamp = mdResult.Timestamps[pointIdx]
				}
				value := 0.0
				if pointIdx < len(mdResult.Values) {
					value = mdResult.Values[pointIdx]
				}
				point := MetricPoint{Timestamp: timestamp}
				if query.Statistic == "Sum" {
					point.Sum = value
				} else {
					// Fill both Average and Maximum so AverageOfAverages and
					// MaxOfMaximums both work for percentage metrics.
					point.Average = value
					point.Maximum = value
					point.SampleCount = 1
				}
				points = append(points, point)
			}
		}
		if output.NextToken == nil {
			break
		}
		nextToken = *(output.NextToken)
	}
	result := MetricResult{
		Namespace: query.Namespace,
		Name:      query.MetricName,
		Points:    points,
	}
	return result, nil
}

// FormatResult renders one metric for stdout.
func FormatResult(label string, result MetricResult) string {
	if len(result.Points) == 0 {
		return fmt.Sprintf("%s: no datapoints in the last hour", label)
	}
	// Restart counters read better as a total than avg/max.
	if result.Name == "pod_number_of_container_restarts" {
		return fmt.Sprintf(
			"%s: %d datapoints, total restarts=%.0f",
			label,
			len(result.Points),
			result.SumOfSums(),
		)
	}
	avg := result.AverageOfAverages()
	maxVal := result.MaxOfMaximums()
	sum := result.SumOfSums()
	return fmt.Sprintf(
		"%s: %d datapoints, avg=%.2f max=%.2f sum=%.2f",
		label,
		len(result.Points),
		avg,
		maxVal,
		sum,
	)
}

// ObservabilityHint explains the most common reason for empty results:
// the ContainerInsights addon is disabled, the region/cluster is wrong,
// or the query hit the empty AWS/ContainerInsights namespace.
func ObservabilityHint(clusterName string, region string) string {
	return fmt.Sprintf(
		"HINT: all queries returned no datapoints for cluster %s in %s. "+
			"Most likely terraform var.enable_observability=false so the "+
			"amazon-cloudwatch-observability addon never published ContainerInsights metrics. "+
			"Check: 1) terraform apply with enable_observability=true, "+
			"2) CLUSTER_NAME/AWS_DEFAULT_REGION match the real cluster, "+
			"3) namespace is ContainerInsights (not AWS/ContainerInsights). "+
			"Debug with: aws cloudwatch list-metrics --namespace ContainerInsights --region %s",
		clusterName,
		region,
		region,
	)
}
