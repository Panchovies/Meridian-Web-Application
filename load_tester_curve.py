import argparse
import math
import statistics
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import UTC, datetime

import requests

DEFAULT_DURATION_MINUTES = 5.0
DEFAULT_PEAK_CONCURRENCY = 50
REQUEST_TIMEOUT = 5
P95 = 0.95

# How many standard deviations wide the bell curve is within the run
# duration. 6 sigma across the duration means the curve is essentially
# zero at t=0 and t=duration, so the ramp genuinely starts/ends slow.
SIGMA_DIVISOR = 6


@dataclass
class RequestResult:
    """Whether a single request succeeded, and how long it took."""

    ok: bool
    latency_seconds: float
    status_code: int | None


def _fire_one(session: requests.Session, url: str) -> RequestResult:
    """Send one GET request and time it, treating any exception as a failure."""
    start = time.perf_counter()
    try:
        response = session.get(url, timeout=REQUEST_TIMEOUT)
    except requests.RequestException:
        latency = time.perf_counter() - start
        return RequestResult(
            ok=False, latency_seconds=latency, status_code=None,
        )
    latency = time.perf_counter() - start
    return RequestResult(
        ok=response.ok,
        latency_seconds=latency,
        status_code=response.status_code,
    )


def build_concurrency_schedule(
    duration_seconds: int, peak_concurrency: int,
) -> list[int]:
    """Return the number of new concurrent requests to fire for each second
    of the run, following a bell curve (Gaussian) that starts near 1,
    ramps up to `peak_concurrency` at the midpoint, then settles back down.
    """
    if duration_seconds <= 0:
        return [peak_concurrency]

    mid = duration_seconds / 2
    sigma = duration_seconds / SIGMA_DIVISOR

    schedule = []
    for t in range(duration_seconds):
        factor = math.exp(-((t - mid) ** 2) / (2 * sigma**2))
        concurrency = max(1, round(peak_concurrency * factor))
        schedule.append(concurrency)
    return schedule


def run_load_test(
    url: str, duration_minutes: float, peak_concurrency: int,
) -> list[RequestResult]:
    """Fire concurrent GETs at the target URL, ramping up and back down
    along a bell curve over `duration_minutes`, topping out at
    `peak_concurrency` concurrent requests around the midpoint.
    """
    duration_seconds = max(1, round(duration_minutes * 60))
    schedule = build_concurrency_schedule(duration_seconds, peak_concurrency)

    results: list[RequestResult] = []
    with (
        requests.Session() as session,
        ThreadPoolExecutor(max_workers=peak_concurrency) as pool,
    ):
        futures = []
        for concurrency in schedule:
            tick_start = time.perf_counter()
            for _ in range(concurrency):
                futures.append(pool.submit(_fire_one, session, url))

            elapsed = time.perf_counter() - tick_start
            time.sleep(max(0.0, 1.0 - elapsed))

        for future in as_completed(futures):
            results.append(future.result())

    return results


def _percentile(values: list[float], fraction: float) -> float:
    """Return the value at the given fraction of a sorted list."""
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(int(len(ordered) * fraction), len(ordered) - 1)
    return ordered[index]


def summarize(
    results: list[RequestResult], started_at: datetime, finished_at: datetime,
) -> None:
    """Print a single aggregate summary block, not one line per request."""
    total = len(results)
    successes = [r for r in results if r.ok]
    failures = [r for r in results if not r.ok]
    latencies = [r.latency_seconds for r in results]
    duration = (finished_at - started_at).total_seconds()

    print("=== Load test summary ===")
    print(f"start:      {started_at.isoformat()}")
    print(f"end:        {finished_at.isoformat()}")
    print(f"duration:   {duration:.2f}s")
    print(f"requests:   {total}")
    print(f"successes:  {len(successes)}")
    print(f"failures:   {len(failures)}")
    if duration > 0:
        print(f"throughput: {total / duration:.1f} req/s")
    if latencies:
        print(f"latency min:    {min(latencies) * 1000:.1f}ms")
        print(f"latency median: {statistics.median(latencies) * 1000:.1f}ms")
        print(f"latency p95:    {_percentile(latencies, P95) * 1000:.1f}ms")
        print(f"latency max:    {max(latencies) * 1000:.1f}ms")


def main() -> None:
    """Parse CLI arguments, run the load test, and print the summary."""
    parser = argparse.ArgumentParser(
        description="Fire a bell-curve-shaped burst of requests at the app "
        "to observe load ramping up and back down in Grafana.",
    )
    parser.add_argument(
        "--url",
        required=True,
        help="e.g. http://<minikube ip>:<nodePort>/health or "
        "http://<elb-hostname>/health",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=DEFAULT_DURATION_MINUTES,
        help="Length of the test in minutes, spanning the full ramp up "
        "and ramp down (default: %(default)s).",
    )
    parser.add_argument(
        "--peak",
        type=int,
        default=DEFAULT_PEAK_CONCURRENCY,
        help="Peak concurrent requests in flight, reached at the midpoint "
        "of the run (default: %(default)s).",
    )
    args = parser.parse_args()

    print(
        f"Ramping up to a peak of {args.peak} concurrent requests at "
        f"{args.url}, spread over {args.duration} minute(s)...",
    )
    started_at = datetime.now(UTC)
    results = run_load_test(args.url, args.duration, args.peak)
    finished_at = datetime.now(UTC)

    summarize(results, started_at, finished_at)


if __name__ == "__main__":
    main()
