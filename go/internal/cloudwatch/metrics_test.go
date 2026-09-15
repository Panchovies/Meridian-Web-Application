package cloudwatch

// Tests use a fake CloudWatchAPI so no network or AWS credentials are needed.
// Every error is assigned to a named variable and checked explicitly.
// From Boris' Repository: https://gitlab.com/mcm-delivery-service-26-08/boris_lipovetsky_palermo_w1

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch/types"
)

// fakeClient returns canned GetMetricData results or a canned error.
type fakeClient struct {
	timestamps []time.Time
	values     []float64
	nextTokens []string
	callCount  int
	failErr    error
}

func (fake *fakeClient) GetMetricData(
	ctx context.Context,
	params *cloudwatch.GetMetricDataInput,
	optFns ...func(*cloudwatch.Options),
) (*cloudwatch.GetMetricDataOutput, error) {
	if fake.failErr != nil {
		return nil, fake.failErr
	}
	if ctx == nil {
		return nil, errors.New("nil context")
	}
	if params == nil {
		return nil, errors.New("nil params")
	}
	fake.callCount++
	output := &cloudwatch.GetMetricDataOutput{
		MetricDataResults: []types.MetricDataResult{
			{
				Id:         params.MetricDataQueries[0].Id,
				Timestamps: fake.timestamps,
				Values:     fake.values,
			},
		},
	}
	// Simulate one page of pagination when nextTokens are provided.
	if len(fake.nextTokens) >= fake.callCount {
		token := fake.nextTokens[fake.callCount-1]
		if token != "" {
			output.NextToken = &token
		}
	}
	return output, nil
}

// TestFetchMetricAverages verifies Average math on canned GetMetricData values.
func TestFetchMetricAverages(t *testing.T) {
	now := time.Now().UTC()
	fake := &fakeClient{
		timestamps: []time.Time{now, now.Add(-5 * time.Minute)},
		values:     []float64{10, 20},
	}
	query := MetricQuery{Namespace: "ContainerInsights", MetricName: "node_cpu_utilization", ClusterName: "test-cluster", Statistic: "Average", Label: "CPU"}
	start := now.Add(-1 * time.Hour)
	result, fetchErr := FetchMetric(context.Background(), fake, query, start, now)
	if fetchErr != nil {
		t.Fatalf("FetchMetric returned error: %v", fetchErr)
	}
	if len(result.Points) != 2 {
		t.Fatalf("expected 2 points, got %d", len(result.Points))
	}
	avg := result.AverageOfAverages()
	if avg != 15 {
		t.Fatalf("expected avg 15, got %v", avg)
	}
	maxVal := result.MaxOfMaximums()
	if maxVal != 20 {
		t.Fatalf("expected max 20, got %v", maxVal)
	}
}

// TestFetchMetricSum verifies Sum math for restart counters.
func TestFetchMetricSum(t *testing.T) {
	now := time.Now().UTC()
	fake := &fakeClient{
		timestamps: []time.Time{now, now.Add(-5 * time.Minute)},
		values:     []float64{2, 3},
	}
	query := MetricQuery{Namespace: "ContainerInsights", MetricName: "pod_number_of_container_restarts", ClusterName: "test-cluster", Statistic: "Sum", Label: "Restarts"}
	start := now.Add(-1 * time.Hour)
	result, fetchErr := FetchMetric(context.Background(), fake, query, start, now)
	if fetchErr != nil {
		t.Fatalf("FetchMetric returned error: %v", fetchErr)
	}
	sum := result.SumOfSums()
	if sum != 5 {
		t.Fatalf("expected sum 5, got %v", sum)
	}
	line := FormatResult(query.Label, result)
	expected := "Restarts: 2 datapoints, total restarts=5"
	if line != expected {
		t.Fatalf("expected %q, got %q", expected, line)
	}
}

// TestFetchMetricError verifies errors from AWS are wrapped, not swallowed.
func TestFetchMetricError(t *testing.T) {
	now := time.Now().UTC()
	sentinel := errors.New("throttled")
	fake := &fakeClient{failErr: sentinel}
	query := MetricQuery{Namespace: "ContainerInsights", MetricName: "node_memory_utilization", ClusterName: "test-cluster", Statistic: "Average", Label: "Memory"}
	start := now.Add(-1 * time.Hour)
	result, fetchErr := FetchMetric(context.Background(), fake, query, start, now)
	if fetchErr == nil {
		t.Fatalf("expected error, got nil with %d points", len(result.Points))
	}
	if len(result.Points) != 0 {
		t.Fatalf("expected 0 points on error, got %d", len(result.Points))
	}
}

// TestFormatResultEmpty verifies the no-datapoints message.
func TestFormatResultEmpty(t *testing.T) {
	result := MetricResult{Namespace: "ContainerInsights", Name: "pod_number_of_container_restarts"}
	line := FormatResult("Pod restarts", result)
	expected := "Pod restarts: no datapoints in the last hour"
	if line != expected {
		t.Fatalf("expected %q, got %q", expected, line)
	}
}

// TestBuildSearchExpression verifies the SEARCH expression uses the right
// namespace (ContainerInsights, not AWS/ContainerInsights).
func TestBuildSearchExpression(t *testing.T) {
	query := MetricQuery{Namespace: "ContainerInsights", MetricName: "node_cpu_utilization", ClusterName: "meridian-cluster", Statistic: "Average", Label: "CPU"}
	expression := BuildSearchExpression(query)
	expected := "SEARCH('{ ContainerInsights,ClusterName } MetricName=\"node_cpu_utilization\" AND ClusterName=\"meridian-cluster\"', 'Average', 300)"
	if expression != expected {
		t.Fatalf("expected %q, got %q", expected, expression)
	}
}
