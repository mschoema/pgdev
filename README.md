# pgdev - PostgreSQL Development Environment Manager

A command-line tool for creating, managing, and interacting with
multiple, isolated PostgreSQL development environments built from source.

## Introduction

**`pgdev`** is a tool designed to simplify the workflow of developers
working on PostgreSQL core or extensions. It automates the entire
process of setting up a development environment, from downloading and
compiling source code to initializing and running the database cluster.

The core philosophy of **`pgdev`** is to provide a flexible and powerful
build system without a rigid configuration framework. It uses simple,
executable shell scripts (`Blueprints`) and a self-contained directory
structure, giving you full control over the build process while
automating the tedious aspects of environment management.

## Core Concepts

The tool is built on a few simple but powerful concepts: a self-contained
directory structure, and a build system based on Blueprints and Templates.

### Directory Structure

**`pgdev`** uses a monolithic directory structure, keeping all tool files
and user-generated instances under a single `~/pgdev` directory. This
makes it easy to find all related files and manage the installation.

```

\~/pgdev/
├── instances/              # User's database instances are created here
│   └── pg18/
│       ├── src/
│       ├── install/
│       ├── data/
│       ├── postgresql.log
│       ├── pgdev.conf
│       └── ...
│
├── templates/              # User's personal templates
├── blueprints/             # User's personal, reusable blueprint scripts
│
└── .core/                  # The tool's internal installation files (hidden)
    ├── bin/
    │   └── pgdev.sh        # The core logic in a portable bash script
    ├── shell/
    │   └── pgdev.sh.env    # Script to be sourced for bash/zsh
    ├── blueprints/         # Default blueprints shipped with the tool
    └── templates/          # Default templates shipped with the tool
        └── base/

````

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
scaffold a new instance.

The tool also supports a **blueprint override system**. When you use a
template, **`pgdev`** will first look for templates in your personal
`~/pgdev/templates/` directory before falling back to the default
templates shipped with the tool in `~/pgdev/.core/templates/`.

## Installation

Installation is a two-step process: first install the core tool, then
configure your shell for seamless integration.

### Step 1: Install the Core Tool

Clone the repository and run the installer script. This will create the
`~/pgdev/.core` directory and copy the necessary files into it.

```bash
gh repo clone mschoema/pgdev
cd pgdev
./install.sh
```

NOTE: The install script above has not been implemented yet. For now,
manually symlink the cloned repo to `~/pgdev/.core`.

```bash
ln -s PATH_TO_PGDEV_GIT_REPO $HOME/pgdev/.core
```

### Step 2: Configure Shell Integration

To enable features like the `pgdev switch` command, you need to
integrate the tool with your shell.

#### For `fish` Users (Recommended)

The best experience for `fish` users is via a Fisher plugin. After
running the main `install.sh` script, install the plugin. The plugin
will automatically check that the core tool is installed.

```fish
# First, ensure you've run ./install.sh from the main repo
fisher install mschoema/pgdev-fish
```

#### For `bash` & `zsh` Users (TODO, this is not implemented yet)

For `bash` and `zsh`, add the following line to your startup file
(`.bashrc` for bash, `.zshrc` for zsh).

```bash
# Add this line to your ~/.bashrc or ~/.zshrc
source "$HOME/pgdev/.core/shell/pgdev.sh.env"
```

After updating your shell file, open a new terminal to start using `pgdev`.

## Command Reference

### Instance Creation & Setup

  * **`pgdev create <name> <template_name>`**: All-in-one: scaffolds, builds, and starts an instance.
  * **`pgdev new <name> <template_name>`**: Scaffolds a new instance directory from a template, but does *not* build it.
  * **`pgdev setup <name>`**: Runs the full `configure` and `build` chain for a scaffolded instance.
  * **`pgdev init <name>`**: Initializes and configures the cluster for a new instance.
  * **`pgdev delete <name>`**: Stops and completely removes an instance directory.

### Daily Management

  * **`pgdev list`**: Lists all instances, their status, port, and PostgreSQL version.
  * **`pgdev start [name]`**: Starts a stopped Postgres instance. Uses the active instance if `<name>` is omitted.
  * **`pgdev stop [name]`**: Stops a running Postgres instance.
  * **`pgdev restart [name]`**: Restarts an instance.
  * **`pgdev status [name]`**: Checks the status of an instance.

### Shell Environment

  * **`pgdev switch <name|default|off>`**: Activates an instance for the current shell session by setting `PATH`, `PGDATA`, etc.
  * **`pgdev default <name>`**: Sets an instance as the default for all new shell sessions.

### Development & Interaction

  * **`pgdev configure <name> <component>`**: (Re-)configures a single component within an instance.
  * **`pgdev build <name> <component>`**: (Re-)compiles a single component within an instance.
  * **`pgdev test <name> <component>`**: Runs the test suite for a single component.
  * **`pgdev psql [name]`**: Connects to the instance using `psql`.
  * **`pgdev logs [name]`**: Tails the main log file for the instance.
  * **`pgdev conf [name]`**: Opens postgresql.conf for the instance using the user's default editor.

## Example Workflow

1.  **Create your main work instance and set it as the default.**

    ```bash
    pgdev create pg18 base
    pgdev default pg18
    ```

2.  **Open a new terminal.** Your default instance is automatically active.

    ```bash
    # No 'switch' needed! The prompt might even show the active instance.
    psql -c "SELECT version();"
    # version
    # ----------------------------------------------------
    # PostgreSQL 18.0 ...
    ```

3.  **Create a separate instance to work on an extension.**

    ```bash
    pgdev create mobility-dev mobilitydb
    ```

4.  **Switch to the new instance for your current session.**

    ```bash
    pgdev switch mobility-dev
    # Switched to pgdev instance: mobility-dev
    ```

5.  **Edit extension code and quickly recompile just that component.**

    ```bash
    # (Make code changes in ~/pgdev/instances/mobility-dev/src/MobilityDB-...)
    pgdev build mobility-dev mobilitydb
    pgdev restart
    ```

## Advanced Concepts

  * **`pgdev.conf`**: This file is auto-generated inside each instance after a successful build (e.g., `~/pgdev/instances/pg18/pgdev.conf`). It stores simple runtime metadata, primarily the **port** number and the PostgreSQL **version** string.

  * **`pgdev.manifest`**: This file is used as a communication channel between blueprints during the build process. It allows blueprints to declare runtime requirements. For example, the MobilityDB blueprint can write `requires_preload=postgis-3` to the manifest. The `pgdev create` command will later read this file and automatically configure `shared_preload_libraries` in `postgresql.conf`, making the blueprints self-describing and modular.

## Uninstalling

To uninstall `pgdev`, you must remove the installed files and undo the shell integration.

1.  **Remove the core installation.**
    ```bash
    rm -rf ~/pgdev/.core
    ```
2.  **Remove the shell integration.**
      * For `fish` users: `fisher remove mschoema/pgdev-fish`.
      * For `bash`/`zsh` users: Remove the `source` line from your `.bashrc` or `.zshrc`.
3.  **Remove your blueprints and templates (optional).**
    ```bash
    rm -rf ~/pgdev/blueprints
    rm -rf ~/pgdev/templates
    ```

**Important**: This process does **not** touch your instance data located in `~/pgdev/instances/`. You must delete those directories manually if you no longer need them.
