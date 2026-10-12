# practiceCLI - Playwright E2E + Jenkins CI

End-to-end UI tests for the [Rahul Shetty Academy practice shop](https://rahulshettyacademy.com/client)
written in **Playwright + TypeScript** using the **Page Object Model (POM)**, wired into an
**automated Jenkins pipeline** that runs on every push and reports results by **email**,
**Allure**, and an auto-filed **Jira** bug on failure.

> **Scope:** the pipeline is automated for **detection and reporting** - it catches failures
> and raises alerts on its own. **Repair is not automated:** fixing broken test code is done
> by a developer (optionally with Claude Code's help) and committed by hand. See
> [Chaos testing](#chaos-testing-fault-injection) and the note under [The automated loop](#the-automated-loop).

Repo: https://github.com/makpowerful/practiceCLI

---

## What the test does

`tests/checkout.spec.ts` logs into the shop, empties the cart, adds 3 random products,
and verifies those same products appear on the checkout page.

> The store currently has only 3 products, so "3 random" picks all of them in a random
> order. The code still picks 3 distinct items if more are added later.

---

## Project structure

```
pages/                      Page Objects
  LoginPage.ts              login form + submit
  DashboardPage.ts          product cards, add-to-cart, open cart
  CartPage.ts               clear cart, read items, checkout
  CheckoutPage.ts           read checkout items, screenshot
tests/
  checkout.spec.ts          the main end-to-end test
  example.spec.ts           Playwright's default samples (safe to delete)
test-data/
  users.ts                  reads login creds from env vars
scripts/
  make_email_report.ps1     builds a JS-free HTML summary for the email
  create_jira_bug.ps1       opens/comments a Jira bug on failure (with dedup)
  inject_fault.ps1          chaos testing: breaks a locator (working copy only)
  zip_report_for_email.ps1  (legacy helper, no longer used by the pipeline)
Jenkinsfile                 the CI pipeline (declarative, Windows agent)
playwright.config.ts        reporters, retries, baseURL, trace/video
.env                        local secrets (git-ignored)
.env.example                template for .env
```

---

## Prerequisites

- **Node.js** 18+ (developed on v24) and npm
- A Playwright browser: `npx playwright install chromium`
- For CI: **Jenkins** (Windows agent) with the plugins listed below

---

## Running locally

1. Install dependencies:
   ```bash
   npm ci
   ```
2. Create your `.env` from the template and fill in the shop login:
   ```bash
   cp .env.example .env
   ```
   ```
   BASE_URL=https://rahulshettyacademy.com
   APP_USER=your-shop-email
   APP_PASSWORD=your-shop-password
   ```
   Credentials are **never hardcoded** - `test-data/users.ts` reads `APP_USER` /
   `APP_PASSWORD` and fails with a clear message if they are missing.
3. Run the test:
   ```bash
   npm run test:checkout            # headless, Chromium
   npm run test:checkout:headed     # watch it in a browser
   npx playwright show-report       # open the HTML report
   ```

> Run **Chromium only** when using the shared account. All runs share one shop account
> (and its server-side cart), so running Chromium/Firefox/WebKit in parallel would make
> them clobber each other's cart.

---

## Reports

| Report | Where | Notes |
|--------|-------|-------|
| Playwright HTML | `playwright-report/` | interactive; `npx playwright show-report` |
| Allure | `allure-results/` -> Jenkins | detailed analysis + history trend |
| JUnit XML | `test-results/junit.xml` | feeds Jenkins' native Test Result trend |

In CI the reporters are set automatically (`process.env.CI`). Trace is captured
`on-first-retry` and video `retain-on-failure`.

---

## CI/CD pipeline (Jenkins)

**Job:** `practiceCLI-playwright` (Pipeline from SCM, `Jenkinsfile`, branch `main`).

**Trigger:** SCM polling `H/2 * * * *` - a push to `main` auto-builds within ~2 minutes.
(GitHub can't webhook into a local Jenkins, so polling is used.)

**Stages:** check tools -> `npm ci` -> install browser -> run tests.

**On every build (`post`):**
- Publish JUnit results + Allure report (archived) + Playwright HTML report
- Build a JS-free HTML summary (`email-report.html`) and **email** it
- **On failure only:** create/comment a **Jira bug** and include its link in the email

### The automated loop

```
push to main  ->  Jenkins polls (~2 min)  ->  build + test
   |-- PASS -> email (HTML summary) + Allure in Jenkins
   `-- FAIL -> email (HTML summary + Jira link) + Allure + Jira bug auto-filed
```

> Jenkins **detects and reports** failures automatically, but it does **not fix** broken
> test code - repair is done by a developer (optionally with Claude Code) and committed by
> hand. Automating repair (an agent that proposes a fix on a branch for review) is a possible
> next step, not something this pipeline does today.

---

## One-time Jenkins setup

### Required plugins
Pipeline, Git, JUnit, HTML Publisher, Credentials Binding, NodeJS, Timestamper,
Email Extension (email-ext), Allure.

### Credentials (Manage Jenkins -> Credentials -> System -> Global)
| ID | Kind | Username | Password |
|----|------|----------|----------|
| `rsa-app-login` | Username with password | shop email | shop password |
| `jira-api` | Username with password | Jira account email | Jira API token |

The IDs must match exactly - the `Jenkinsfile` references them.

### Email (SMTP)
*Manage Jenkins -> System -> Extended E-mail Notification* (this is the section
`emailext` uses - **not** the plain "E-mail Notification" one):
- SMTP server `smtp.gmail.com`, port `465`, SSL on
- SMTP auth: **full** Gmail address + a Gmail **App Password** (needs 2-Step Verification)
- Set the same address as the **System Admin e-mail address**

### Allure
Configure an Allure Commandline tool (Manage Jenkins -> Tools). The pipeline auto-selects
the only installation.

---

## Jira integration

On a failed build, `scripts/create_jira_bug.ps1`:
- parses `test-results/junit.xml` for failed tests,
- **dedups** via JQL (label `ci-auto-failure`): if an unresolved auto-bug for this job
  exists it adds a **comment** instead of a duplicate; otherwise it **creates** a Bug,
- writes the issue key to `jira-issue.txt` so the email can link to it.

Target: project **`SCRUM`** on `https://makpowerful.atlassian.net`, issue type **Bug**.

---

## Chaos testing (fault injection)

A parameter-gated **"Fault injection (chaos)"** stage deliberately breaks a locator so you
can verify, hands-free, that the pipeline **detects and reports** a regression (test fails
-> email -> Jira bug). This is *fault injection / chaos testing* - it exercises the
**detect + alert** path. It does **not** self-heal; fixing the code still needs a human.

**How it works**
- A boolean parameter **`INJECT_FAULT`** (default **off**) controls it. Normal pushes and
  unticked builds run the real tests and stay green.
- When enabled, the stage runs `scripts/inject_fault.ps1`, which rewrites a locator in the
  **working copy only** (`DashboardPage.goToCart` URL assertion) and logs the exact
  before/after.
- The change is **never committed or pushed**. Jenkins force-checks-out the branch on every
  build, so the fault is discarded on the next run - no dirty history, no broken `main`, and
  no build loop (which committing the break *would* cause, since SCM polling rebuilds on push).

**How to run it**
- Jenkins UI: *Build with Parameters* -> tick **INJECT_FAULT** -> **Build**.
- Or via the API: `buildWithParameters?BROWSER=chromium&INJECT_FAULT=true`.

The failing chaos build then emails the HTML summary (with the Jira link) and auto-files or
comments the Jira bug, exactly like a real regression.

> Want true self-healing (an agent that edits and pushes a fix automatically)? That's a
> separate, larger build with real safety trade-offs - any auto-push should be gated behind
> review.

---

## Gotchas (learned the hard way)

- **Never write the `Jenkinsfile` with PowerShell `Set-Content`/`Out-File`/`>` using
  `-Encoding utf8`** - Windows PowerShell adds a UTF-8 **BOM** that makes Groovy fail to
  compile (`MissingPropertyException: No such property: <BOM>`). Use an editor that writes
  UTF-8 **without BOM**.
- **Gmail blocks the interactive Playwright report as an attachment** - a failing build's
  report bundles trace `.zip`, `.webm` videos and trace-viewer `.js`, and Gmail rejects
  those (`552-5.7.0`). That's why the email attaches a **JS-free HTML summary** and links
  to the full report in Jenkins instead.
- **Shared cart:** one shop account = one server-side cart, so builds never run in parallel
  (`disableConcurrentBuilds()`), and the test clears the cart before each run.

---

## npm scripts

| Script | Description |
|--------|-------------|
| `npm run test:checkout` | run the checkout test (Chromium, headless) |
| `npm run test:checkout:headed` | same, with a visible browser |
