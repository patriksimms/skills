---
name: setup-ts-project
description: Add development tooling like testing, formatting, linting, CI, database, docker and renovate for typescript project. Use when user wants to setup a new typescript project or add standard tooling or mentions "setup new typescript project".
---

# Setup ts project

## Package manager
THe project should use Bun as a package manager & task runner.

## Testing
Use vitest in the project and install it as a devDependency. Create a `test` script in package.json script that runs vitest in run mode `vitest --run`

## Linting
Use oxlint in the newest version, install it as a devDependency. Create a `lint` package.json script that runs `oxlint` and a `lint:fix` script that runs `oxlint --fix`. Use the provided config file `references/oxlint.config.ts`


## Formatting
Use oxfmt in the newest version, install it as a devDependency. Create a `fmt` package.json script that runs `oxfmt`, Use the provided config file `references/oxfmt.config.ts`

## Renovate
Setup Renovate for dependency scanning. Create a `renovate.json` file based on `references/renovate.json`. Adjust the package rules based on the fact if the project should contain Frontend code or not

## CI
Ask the user if this is a gitlab project. If yes, please add these 2 jobs. Also make sure to set the variable for the Bun version in the variables

```yaml
variables:
  BUN_VERSION: 1.3.10

test:
  stage: test
  variables:
    stage: dev
  image: oven/bun:${BUN_VERSION}-alpine
  needs: []
  script:
    - printf '%s\n' "$GITLAB_NPMRC" >".npmrc"
    - bun install --frozen-lockfile --ignore-scripts
    - bun run test:ci

lint:
  stage: test
  image: docker-cache.esome.info/oven/bun:${BUN_VERSION}-alpine
  needs: []
  allow_failure: true
  script:
    - printf '%s\n' "$GITLAB_NPMRC" >.npmrc
    - bun install --frozen-lockfile
    - bun run lint

```

## Docker Setup
Create a dockerfile for Bun in `.docker/Dockerfile.bun`, use the template from `references/Dockerfile.bun`.
Also setup docker compose with the example from `references/docker-compose.yml`. Only include the postgres container if the project is a backend project and needs a DB.

## Database
If the user wants to use the skill for a project that needs a database, setup drizzle with `references/drizzle.config.ts` in project root and `references/dbClient.ts` in a `src` folder.

## .envrc.example
Create an `.envrc.example` file in the project. When a database is used, create sensible default variables there for `DB_USER`, `DB_PASSWORD` and `DB_NAME`. The variables are used in the dockerfile
