# ════════════════════════════════════════════════════════════════════════════════
#  JJ Thomson Books — Jupyter Book Docker Image
#
#  Image name:   jj-thomson-jb-base    (build environment, used locally)
#  Image name:   jj-thomson-ci-build   (self-contained build, used in CI/CD)
#  Image name:   jj-thomson-serve      (nginx serving built HTML, optional local preview)
#
#  Stages
#  ──────
#  base       Python 3.11 + jupyter-book installed.
#             Used for LOCAL development (source mounted as volume).
#             docker build --target base ...
#
#  ci-build   Extends base: copies the entire repo into the image and runs
#             `jupyter-book build /books`.  Self-contained, no mounts.
#             Used in CI/CD pipelines (GitHub Actions).
#             docker build --target ci-build ...
#
#  serve      Nginx serving the HTML output produced by ci-build.
#             Useful for smoke-testing the final HTML locally.
#             docker build --target serve ...    # builds everything
#
#  Build args
#  ──────────
#  PYTHON_VERSION   Python image tag        (default: 3.11)
#  JB_VERSION       jupyter-book version    (default: 1.0.4)
#  NGINX_VERSION    nginx image tag         (default: 1.27-alpine)
# ════════════════════════════════════════════════════════════════════════════════

ARG PYTHON_VERSION=3.11
ARG JB_VERSION=1.0.4
ARG NGINX_VERSION=1.27-alpine

# ── base: build environment ────────────────────────────────────────────────────
FROM python:${PYTHON_VERSION}-slim AS base

ARG JB_VERSION

LABEL org.opencontainers.image.title="jj-thomson-jb-base"
LABEL org.opencontainers.image.description="Jupyter Book ${JB_VERSION} build environment for J.J. Thomson's Works"

RUN pip install --no-cache-dir "jupyter-book==${JB_VERSION}"

WORKDIR /books

# Default command for use with docker compose run
CMD ["jupyter-book", "build", "/books"]

# ── ci-build: self-contained build for CI/CD pipelines ────────────────────────
FROM base AS ci-build

LABEL org.opencontainers.image.title="jj-thomson-ci-build"
LABEL org.opencontainers.image.description="Self-contained Jupyter Book build — copies source and builds HTML"

# Copy all book content (respects .dockerignore at repo root)
COPY . .

# Build; --keep-going surfaces all warnings but does not abort on the first one
RUN jupyter-book build /books --keep-going

# ── serve: nginx serving the built HTML ───────────────────────────────────────
FROM nginx:${NGINX_VERSION} AS serve

LABEL org.opencontainers.image.title="jj-thomson-serve"
LABEL org.opencontainers.image.description="Nginx serving Jupyter Book HTML"

COPY --from=ci-build /books/_build/html /usr/share/nginx/html

EXPOSE 80
