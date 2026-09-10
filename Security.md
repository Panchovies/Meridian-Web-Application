# Vulnerability Report

## Wednesday, September 9th

### `Trivy`

This was when `Trivy` was first implemented into the pipeline. Before that,
there were no vulnerability checks.

The initial `python:3.13-slim` scan reported 54 findings: 51 HIGH and 3
CRITICAL. The findings were split between 52 Debian package findings and two
Python package findings.

| Finding                    | Severity        | Affected component                    | Fix available                         | Remediation                                                                                 |
| -------------------------- | --------------- | ------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------- |
| 52 Debian package findings | HIGH / CRITICAL | Debian packages in `python:3.13-slim` | No fixed versions reported by `Trivy` | Replaced the `slim` base image with `alpine`, removing the affected packages from the image |
| `GHSA-6v7p-g79w-8964`      | HIGH            | `msgpack` 1.1.2                       | Yes, 1.2.1                            | Removed `pip` from the runtime image, which also removed the vulnerable copy                |
| `CVE-2025-47273`           | HIGH            | `setuptools` 70.3.0                   | Yes, 78.1.1                           | Removed `pip` from the runtime image, which also removed the vulnerable copy                |

The 52 Debian findings were not individually reproduced here because `Trivy`
reported no fixed versions for them. Replacing the base image removed the
affected Debian package surface rather than individually upgrading packages that
had no available fix.

The first Alpine build reduced the base-image findings to seven HIGH findings,
all associated with `libuuid` 2.42.1-r0.

| CVE              | Severity | Affected component  | Fix available     | Remediation                            |
| ---------------- | -------- | ------------------- | ----------------- | -------------------------------------- |
| `CVE-2026-53612` | HIGH     | `libuuid` 2.42.1-r0 | Yes, 2.42.3-r0/r1 | Upgraded with `apk upgrade --no-cache` |
| `CVE-2026-53613` | HIGH     | `libuuid` 2.42.1-r0 | Yes, 2.42.3-r0/r1 | Upgraded with `apk upgrade --no-cache` |
| `CVE-2026-53614` | HIGH     | `libuuid` 2.42.1-r0 | Yes, 2.42.3-r0/r1 | Upgraded with `apk upgrade --no-cache` |
| `CVE-2026-76642` | HIGH     | `libuuid` 2.42.1-r0 | Yes, 2.42.3-r0/r1 | Upgraded with `apk upgrade --no-cache` |
| `CVE-2026-78408` | HIGH     | `libuuid` 2.42.1-r0 | Yes, 2.42.3-r0/r1 | Upgraded with `apk upgrade --no-cache` |
| `CVE-2026-78409` | HIGH     | `libuuid` 2.42.1-r0 | Yes, 2.42.3-r0/r1 | Upgraded with `apk upgrade --no-cache` |
| `CVE-2026-78410` | HIGH     | `libuuid` 2.42.1-r0 | Yes, 2.42.3-r0/r1 | Upgraded with `apk upgrade --no-cache` |

The Alpine findings were fixed with:

```dockerfile
RUN apk upgrade --no-cache
```

`apk update` was intentionally not used. `apk upgrade --no-cache` fetches the
package index it needs without leaving the index files in the image layer.
Running `apk update` beforehand would leave the downloaded `APKINDEX` files
behind, making the separate update redundant and unnecessarily increasing the
image layer.

Two additional findings were unrelated to the base image and involved Python
packages: `msgpack` and `setuptools`. These findings were initially confusing
because the versions reported by `Trivy` did not correspond to the versions
explicitly installed by the Dockerfile.

`setuptools` was a package I was installing, but the vulnerable version reported
by `Trivy` was 70.3.0, while the Dockerfile-installed version was 83.0.0.
`Trivy` also reported `msgpack` 1.1.2 even though `msgpack` was not explicitly
listed as a dependency in the Dockerfile.

The important distinction was that these were not application dependencies. Both
findings were reported under a `Python` target without a dependency file path.
The explicitly installed `setuptools` 83.0.0 was separately present as
`setuptools-83.0.0.dist-info` and had no findings. The vulnerable 70.3.0 version
was a second copy carried inside `pip`'s packages. Likewise, the vulnerable
`msgpack` copy was part of `pip`'s dependencies.

This explained why changing the `pip` version changed the findings. I initially
diagnosed the problem as being caused by `pip` 26.2.1 carrying those outdated
packages and switched from `26.2.1` to `26.1.1`, which removed the findings.

However, the better solution was to avoid putting the installer into the runtime
image at all.

I separated `requirements.txt` into runtime and developer requirements so that
the Dockerfile no longer needed to retain the development tooling and its
installer in the final image. I also explicitly removed `pip` from the runtime
image as an additional measure:

```bash
RUN rm -rf \
        /usr/local/lib/python3.13/site-packages/pip \
        /usr/local/lib/python3.13/site-packages/pip-*.dist-info \
        /usr/local/bin/pip \
        /usr/local/bin/pip3*
```

This removed the vulnerable copies of `msgpack` and `setuptools` from the
runtime image and resolved the remaining `Trivy` findings.

### `pip-audit`

`pip-audit` was also installed as part of the pipeline to audit Python
dependencies. Its findings were separate from the `Trivy` image scan because the
audit runs during the `checks` stage rather than against the final runtime
image.

The first `pip-audit` run reported the following:

| Finding           | Severity | Affected component  | Fix available | Remediation                                          |
| ----------------- | -------- | ------------------- | ------------- | ---------------------------------------------------- |
| `PYSEC-2026-196`  | —        | `pip` 24.0          | Yes, 26.2     | Pinned `pip` 26.2.1 in `requirements-dev.txt`        |
| `PYSEC-2026-1795` | —        | `pip` 24.0          | Yes, 26.2     | Pinned `pip` 26.2.1 in `requirements-dev.txt`        |
| `PYSEC-2026-1796` | —        | `pip` 24.0          | Yes, 26.2     | Pinned `pip` 26.2.1 in `requirements-dev.txt`        |
| `PYSEC-2026-2875` | —        | `pip` 24.0          | Yes, 26.2     | Pinned `pip` 26.2.1 in `requirements-dev.txt`        |
| `PYSEC-2026-2876` | —        | `pip` 24.0          | Yes, 26.2     | Pinned `pip` 26.2.1 in `requirements-dev.txt`        |
| `PYSEC-2026-3721` | —        | `pip` 24.0          | Yes, 26.2     | Pinned `pip` 26.2.1 in `requirements-dev.txt`        |
| `PYSEC-2026-3447` | —        | `setuptools` 79.0.1 | Yes, 83.0.0   | Pinned `setuptools` 83.0.0 in `requirements-dev.txt` |

`pip-audit` does not report severity for these `PYSEC` advisories, so the
severity field is shown as `—` rather than assigning a severity that the tool
does not provide.

These findings were not caused by packages installed into the runtime image.
`pip-audit` was run without an `-r` argument, so it audited the packages present
in the `checks` job's Python environment. That environment includes the
`ci-tools` image's own toolchain as well as packages installed by the pipeline.

At the time of the first audit, `requirements-dev.txt` did not explicitly name
`pip` or `setuptools`, so the versions reported by `pip-audit` (`pip` 24.0 and
`setuptools` 79.0.1) came from the runner image rather than from versions this
repository had selected.

Pinning both packages in `requirements-dev.txt` was therefore used to make the
versions explicit and ensure the `checks` environment uses versions without the
reported vulnerabilities:

```text
pip==26.2.1

setuptools==83.0.0
```

This also restores the explicit pins that existed before the separation of
runtime and developer requirements.

A consequence of this approach is that a future vulnerability in `pip` or
another Python tool already present in the `ci-tools` runner image can cause
`pip-audit` to fail even when the application itself has not changed. In that
case, the failure needs to be distinguished from an application dependency
vulnerability and addressed by updating or pinning the affected development
tooling.

### Final Result

The vulnerability work addressed the findings at three separate layers:

1. **Base image vulnerabilities** were reduced by replacing `python:3.13-slim`
   with Alpine and upgrading its packages with `apk upgrade --no-cache`.

2. **Runtime Python vulnerabilities** were removed by keeping development
   dependencies separate and removing `pip` and its packages from the runtime
   image.

3. **Development environment vulnerabilities** found by `pip-audit` were
   addressed by explicitly pinning `pip==26.2.1` and `setuptools==83.0.0` in
   `requirements-dev.txt`.

The resulting image passed the `Trivy` vulnerability scan, while the development
environment dependencies were separately checked by `pip-audit`.

## Thursday, September 10th

### Network Security

#### Security Groups

Some rules in the security groups were too permissive, as well as some parts
missing.

- Added a 443 ingress rule to the ALB, it was missing previously
- The egress was overly permissive so the `0.0.0.0/0` was scoped down to the
  `5000` port, inside the VPC
- Added a security group rule for the EKS cluster, allowing traffic to EKS nodes
  from elsewhere inside the VPC

#### Encryption

Enabled encryption on S3 buckets using AWS KMS.

#### Audit Logging

The cluster already had all 5 logging types enabled correctly.

#### Public Access

Public access for the S3 buckets was enabled, with all four flags set `true`.

#### CloudWatch Logs Retention

The retention period was set to 14 days, which is overkill for this environment.
It was reduced to 7 days.
