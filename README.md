# Agent Skills

A collection of agent skills that extend capabilities across planning, development, and tooling.

The skills use CLIs such as `td`, `linear`, and `glab` for using task management tools instead of GitHub issues.

> This is heavily inspired from https://github.com/mattpocock/skills

Skills and commands that are no longer actively maintained are available in the [deprecated folder](./deprecated/README.md).

## Planning & Design

These skills help you think through problems before writing code.

* product-discovery — Shape rough product ideas, uncover important unknowns, research options, and recommend a direction without implementation.

```sh
npx skills@latest add patriksimms/skills/product-discovery
```

* write-symphony-issue — Draft Symphony-ready GitLab issues with acceptance criteria and validation steps, then create them with `glab` after human confirmation.

```sh
npx skills@latest add patriksimms/skills/write-symphony-issue
```

* setup-ts-project - Add development tooling like testing, formatting, linting, CI, database, docker and renovate for typescript project.

```sh
npx skills@latest add patriksimms/skills/setup-ts-project
```

## Development Workflow

These skills help with day-to-day git and debugging workflows.

* deliver-change - Deliver a GitHub or GitLab change from a clarified outcome through implementation, tests, green checks, and review loops until the pull or merge request is ready for human review.

```sh
npx skills@latest add patriksimms/skills/deliver-change
```

* commit - Create a well-formed git commit from current changes using session history for rationale and summary.

```sh
npx skills@latest add patriksimms/skills/commit
```
