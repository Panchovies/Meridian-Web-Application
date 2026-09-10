# Vulnerability Report

## `Trivy`

### Wednesday, September 9th

This was when `Trivy` was first implemented onto the pipeline. Before that,
there were no vulnerability checks. `Trivy` found 54 total problems with the
built image. The first 52 were about the base image itself, which at the time
was `python:3.13-slim`. `slim` came equipped with many vulnerabilities that had
no fixed versions outlined by `Trivy`. This led me to changing the image from
`slim` to `alpine`, which only then gave 7 issues with the base image, all of
which were fixed simply running `RUN apk update && apk upgrade --no-cache` in
the Dockerfile.

Two more issues came up that did not have anything to do with the base image,
but with two python packages: `msgpack` and `setuptools`. `setuptools` was in
fact a package I was installing, however the version that `Trivy` listed was not
the version that Dockerfile was installing (70.3.0 vs 83.0.0). `msgpack` on the
other hand, was being found by `Trivy` with no indication of it being installed
in the Dockerfile. Initially, I had diagnosed the problem as being an issue with
the `pip` version, with `26.2.1` installing those outdated packages. I switched
from `26.2.1 -> 26.1.1`, which fixed the issue. However a better solution was to
separate my `requirements.txt` file into two parts: a developer and
non-developer file. This avoided the Dockerfile explicitly downloading `pip` and
making the image smaller, but I still added this argument to make sure it was
gone:

```bash
RUN rm -rf \
        /usr/local/lib/python3.13/site-packages/pip \
        /usr/local/lib/python3.13/site-packages/pip-*.dist-info \
        /usr/local/bin/pip \
        /usr/local/bin/pip3*
```

That solved all vulnerabilities found by `Trivy`.

I also installed `pip-audit` as part of the pipeline, which returned issues with
the versions of `pip` and `setuptools` I was using. This is not because they
were installed into the image, but because `pip-audit` ran in the `checks` stage
of the pipeline, which explicitly adds the developer requirements for that
stage. The fix was simple: explicitly add the correct versions of `pip` and
`setuptools` to `requirements-dev.txt` (`pip`:26.2 and `setuptools`:83.0.0).
