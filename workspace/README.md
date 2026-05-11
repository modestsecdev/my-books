# J.J. Thomson's Works — Jupyter Book Site

This repository contains three books by **J.J. Thomson** rendered as a single
[Jupyter Book](https://jupyterbook.org/) website, built and deployed via Docker.

The markdown source files are **not committed to GitHub** — only the build
infrastructure (in `workspace/`) and the rendered HTML (pushed to the `gh-pages`
branch by `workspace/deploy.ps1`) live on GitHub.

---

## Repository Layout

```
d:\dev\books\                       <- repo root
|
|-- _config.yml                     # Jupyter Book configuration
|-- _toc.yml                        # Table of contents (references book dirs)
|-- index.md                        # Site landing page
|
|-- elctricity-magnetism/           # Book 1  [local only, gitignored]
|-- Electricity-matter/             # Book 2  [local only, gitignored]
|-- Recollections-And-Reflections/  # Book 3  [local only, gitignored]
|
|-- _build/html/                    # Build output [gitignored; deployed via deploy.ps1]
|
|-- workspace/                      <- ALL build infrastructure
|   |-- Dockerfile                  # Multi-stage image (base / ci-build / serve)
|   |-- deploy.ps1                  # Local build-and-deploy script
|   `-- README.md                   # This file
|
|-- docker-compose.yml              # Local build & preview workflow
|-- .dockerignore                   # Keeps Docker build context lean
`-- .gitignore                      # Excludes book dirs, _build/, per-book workspace/
```

> **main branch (GitHub):** `_config.yml`, `_toc.yml`, `index.md`,
> `workspace/`, `docker-compose.yml`, `.*ignore` files.
>
> **gh-pages branch (GitHub):** The rendered HTML — deployed by `deploy.ps1`.
>
> **Local only:** All three book folders with markdown + images.

---

## Docker Images

| Image name | Stage | Description |
|---|---|---|
| `jj-thomson-jb-base:latest` | `base` | Python 3.11 + jupyter-book 1.0.4. Used for **local builds** with source mounted as a volume. No source files baked in. |
| `jj-thomson-ci-build:latest` | `ci-build` | Extends base — copies full repo source and runs `jupyter-book build /books`. Self-contained. |
| `jj-thomson-serve` | `serve` | nginx:1.27-alpine serving the HTML output from ci-build. For local smoke-testing. |

Build args (override at build time with `--build-arg`):

| ARG | Default | Purpose |
|---|---|---|
| `PYTHON_VERSION` | `3.11` | Python base image tag |
| `JB_VERSION` | `1.0.4` | jupyter-book pip version |
| `NGINX_VERSION` | `1.27-alpine` | nginx image tag |

---

## Local Workflow

All commands are run from the **repository root** (`d:\dev\books\`).

### 1 — First-time setup (build the base image)

```powershell
docker compose build build
```

### 2 — Build the book

```powershell
docker compose run --rm build
```

Mounts the entire repo as `/books`; runs `jupyter-book build /books`.
Output lands in `_build/html/` on the host (gitignored).

### 3 — Preview at http://localhost:8080

```powershell
docker compose up serve
# Ctrl-C to stop
```

### 4 — Rebuild after content changes

```powershell
docker compose run --rm build
# Refresh the browser — nginx picks up the new files automatically.
```

### 5 — Force a clean rebuild

```powershell
docker compose run --rm build jupyter-book clean /books
docker compose run --rm build
```

---

## Deploying to GitHub Pages (HTML only)

`workspace/deploy.ps1` builds locally first, verifies success, then pushes
**only `_build/html/`** to the `gh-pages` branch.

```powershell
# Build + deploy in one step:
.\workspace\deploy.ps1

# Skip the Docker build (if you just built):
.\workspace\deploy.ps1 -SkipBuild

# Dry run (no push):
.\workspace\deploy.ps1 -DryRun
```

**One-time GitHub Pages setup:**

1. **Settings → Pages → Source** → "Deploy from a branch"
2. Branch: `gh-pages`, folder: `/ (root)` → Save

After the first `deploy.ps1` run, GitHub Pages will be live at:
`https://<org>.github.io/<repo>/`

**Typical workflow:**

```
Edit markdown locally
        |
docker compose run --rm build      <- verify at http://localhost:8080
        |
.\workspace\deploy.ps1             <- push _build/html/ to gh-pages
        |
GitHub Pages serves the HTML
```

---

## Adding a New Book

1. Create a new folder, e.g. `my-new-book/`, with `ch1.md`, `ch2.md`, …
2. Add `.gitignore` inside it:
   ```
   workspace/
   ```
3. Add the book to `_toc.yml` at the repo root:
   ```yaml
   - caption: "My New Book Title"
     chapters:
       - file: my-new-book/ch1
       - file: my-new-book/ch2
   ```
4. Build and preview locally, then deploy:
   ```powershell
   docker compose run --rm build
   docker compose up serve        # verify
   .\workspace\deploy.ps1
   ```

---

## Pinning and Upgrading Versions

Edit the `ARG` defaults in `workspace/Dockerfile`, then rebuild the image:

```powershell
docker compose build --no-cache build
docker compose run --rm build
```

See the [Jupyter Book changelog](https://github.com/executablebooks/jupyter-book/blob/master/CHANGELOG.md) before upgrading.
