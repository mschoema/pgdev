pgdev - PostgreSQL Development Environment Manager
================================================

## Introduction

**`pgdev`** is a command-line tool designed to simplify the management of
PostgreSQL development environments. It's built for developers working
on PostgreSQL core, extensions, or any project that requires building
PostgreSQL from source. The tool automates creating, managing, and
interacting with multiple, isolated instances of PostgreSQL, each
potentially built from a different source branch and running on a
different port.

The core philosophy of **`pgdev`** is to provide a flexible and powerful
build system without a rigid configuration framework. It relies on
simple, executable scripts and a self-contained directory structure,
giving you full control over the build process while automating the
tedious parts of environment management.

***

## Core Concepts

The tool is built on a few simple but powerful concepts: self-contained
instances, and a build system based on blueprints and templates.

### Instance Directory Structure

The primary unit of organization in **`pgdev`** is the "instance". Each
instance is a single, self-contained directory within `~/pgdev/` that
holds everything required for that environment. This ensures instances
are completely isolated and can be easily managed without side effects.

A typical instance directory has the following structure:
```

\~/pgdev/my-pg-instance/
├── 01-postgres.configure.sh  \# Blueprint scripts defining the build
├── 01-postgres.build.sh
├── 02-postgis.configure.sh
├── 02-postgis.build.sh
│
├── src/                      \# Directory where source code is cloned
├── install/                  \# The installation prefix (bin, lib, etc.)
├── data/                     \# The PostgreSQL data directory (from initdb)
├── logs/                     \# Build logs and server logs
└── pgdev.conf                \# Stores runtime metadata (port, version)

```

### Blueprints and Templates

Instead of a rigid YAML or TOML file, the build process is defined by
**Blueprints**. A blueprint is a set of simple, executable shell
scripts for a *single component* (like PostgreSQL or an extension).
These scripts map to a component's lifecycle:
* **`.configure.sh`**: Clones the source and runs configuration.
* **`.build.sh`**: Compiles and installs the component.
* **`.test.sh`**: Runs the component's test suite.

A **Template** is a pre-made collection of blueprints that defines a
complete instance. For example, you might have a `postgres-only`
template for core development and a `postgres-postgis` template for
extension work. The `pgdev new` command uses these templates to
scaffold a new instance, which you can then customize before building.

***

## Command Reference

### Instance Creation & Setup
* **`pgdev create <name> --template <tmpl> [--port <num>]`**: The main all-in-one command. It scaffolds an instance from a template, builds all components, initializes the database, configures it, and starts the server.
* **`pgdev new <name> --template <tmpl>`**: Scaffolds a new instance directory and its blueprint scripts from a template, but does *not* build it. This allows you to customize the scripts before compilation.
* **`pgdev setup <name>`**: Runs the full `configure` and `build` chain for an instance that has been scaffolded with `new`.

### Daily Management
* **`pgdev list`**: Lists all managed instances, their status (running/stopped), port, and PostgreSQL version.
* **`pgdev start [name]`**: Starts a stopped Postgres instance. Uses the active instance if `<name>` is omitted.
* **`pgdev stop [name]`**: Stops a running Postgres instance.
* **`pgdev restart [name]`**: Restarts an instance.
* **`pgdev delete <name>`**: Stops and completely removes an instance and all its files.

### Shell Environment
* **`pgdev switch <name>`**: Activates a specific instance for the current shell session by setting `PATH`, `PGDATA`, `PGPORT`, etc.
* **`pgdev default <name>`**: Sets an instance as the system-wide default for all new shell sessions by creating a stable symlink.

### Development & Interaction
* **`pgdev build <name> <component>`**: Re-compiles a single component within an instance (e.g., `pgdev build my-instance postgis`).
* **`pgdev test <name> <component>`**: Runs the test suite for a single component.
* **`pgdev psql [name]`**: Connects to the instance using `psql`.
* **`pgdev logs [name]`**: Tails the main log file for the instance.

***

## Shell Integration

For maximum portability, the core logic of **`pgdev`** is a single `bash`
script. However, to enable powerful features like the `switch` command,
a hybrid approach is used. You install a lightweight wrapper function
for your preferred shell (`fish`, `zsh`, etc.).

This wrapper is essential because a script cannot change its parent
shell's environment. When you run `pgdev switch my-instance`, the `bash`
script *prints* the necessary `export` or `set` commands. The shell
wrapper then captures and *evaluates* this output in your current
session, seamlessly modifying your environment. This also enables rich,
context-aware autocompletions.

***

## Advanced Concepts

While the blueprint system is simple on the surface, it uses a couple
of files for coordination:
* **`pgdev.conf`**: This file is auto-generated inside each instance after a successful build. It stores simple runtime metadata, primarily the **port** number chosen during creation and the PostgreSQL **version** string captured from `pg_config`. This allows other commands to easily query the instance's state.
* **`pgdev.manifest`**: This file acts as a communication channel between blueprints during the build process. It's used for advanced configuration. For example, the MobilityDB blueprint can write `requires_preload=postgis-3` to the manifest. The `pgdev create` command will later read this file and automatically configure `shared_preload_libraries` in `postgresql.conf`, making the blueprints self-describing and modular.
