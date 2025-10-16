#!/bin/bash

# --- Boilerplate and Error Handling ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipelines return the exit status of the last command to exit with a
# non-zero status, or zero if all commands exit successfully.
set -o pipefail

# --- Global Constants ---
# Define the root directory for all pgdev operations.
# The user's instances and the tool's core files live here.
PGDEV_ROOT="$HOME/pgdev"
# Define the path to the tool's internal files.
CORE_DIR="$PGDEV_ROOT/.core"
# Define the path where user-generated instances are stored.
INSTANCES_DIR="$PGDEV_ROOT/instances"

# --- Helper Functions ---
# These functions handle common tasks used by multiple commands.

# A simple colorized message printer.
# Usage: msg_info "This is an info message."
msg_info() {
	echo -e "\033[0;32m[INFO]\033[0m $1"
}
# Usage: msg_info "This is an error message."
msg_error() {
	echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

# A function to check if an instance exists and is valid.
# Usage: check_instance_exists "my-instance"
check_instance_exists() {
	local instance_name=$1
	if [ ! -d "$INSTANCES_DIR/$instance_name" ]; then
		msg_error "Instance '$instance_name' not found."
		return 1
	fi
}

# Gets the target instance name from the argument or the active environment.
# Fails with an error message if no instance can be determined.
get_instance_name() {
	local instance_name="${1:-${PGDEV_INSTANCE-}}"

	# If we don't have a name, then it's an error.
	if [[ -z "$instance_name" ]]; then
		msg_error "No instance specified and no environment is active."
		return 1
	fi

	# If we got a name, check that it is valid.
	check_instance_exists "$instance_name" || return 1

	# Print the name for command substitution.
	echo "$instance_name"
}

# Reads a specific key from an instance's pgdev.conf file.
# Usage: port=$(get_instance_config "my-instance" "port")
get_instance_config() {
	local instance_name=$1
	local config_key=$2
	local config_file="$INSTANCES_DIR/$instance_name/pgdev.conf"

	if [ ! -f "$config_file" ]; then
		msg_error "Configuration file for '$instance_name' not found."
		return 1
	fi

	grep "^$config_key=" "$config_file" | cut -d'=' -f2
}

# Finds the next available TCP port, starting from 5432.
# It checks all existing pgdev.conf files to determine which ports are in use.
find_available_port() {
	# Gather all ports currently in use from existing instances' config files.
	local used_ports
	if [ -d "$INSTANCES_DIR" ] && [ -n "$(ls -A "$INSTANCES_DIR")" ]; then
		# This command finds all pgdev.conf files, extracts the 'port=...' line,
		# and cuts out just the number.
		used_ports=$(grep '^port=' "$INSTANCES_DIR"/*/pgdev.conf | cut -d'=' -f2)
	else
		# If no instances exist, the list is empty.
		used_ports=""
	fi

	local port=5432
	# Loop indefinitely until an open port is found.
	while true; do
		# Check if the current port is in the list of used ports.
		# `grep -q -w` searches for the exact port number quietly.
		# The `!` inverts the result, so the 'if' block runs when the port is *not* found.
		if ! echo "$used_ports" | grep -q -w "$port"; then
			# If the port is not in the list, it's available.
			echo "$port"
			return 0
		fi
		# If the port was found, increment and check the next one.
		((port++))
	done
}

# --- Command Functions ---
# Each subcommand has its own dedicated function.

cmd_new() {
	# --- Argument Parsing ---
	if [ $# -ne 2 ]; then
		msg_error "Usage: pgdev new <instance_name> <template_name>"
		return 1
	fi
	local instance_name=$1
	local template_name=$2
	shift 2

	# --- Validation ---
	local instance_dir="$INSTANCES_DIR/$instance_name"
	local template_dir="$CORE_DIR/templates/$template_name"

	if [ -d "$instance_dir" ]; then
		msg_error "Instance '$instance_name' already exists."
		return 1
	fi
	if [ ! -d "$template_dir" ]; then
		msg_error "Template '$template_name' not found in '$CORE_DIR/templates'."
		return 1
	fi

	# --- Scaffolding ---
	msg_info "Scaffolding new instance '$instance_name' from template '$template_name'..."
	mkdir -p "$instance_dir"
	# Copy the contents of the template directory into the new instance directory.
	cp -r "$template_dir/." "$instance_dir/"
	# Create the empty manifest file for the build process.
	touch "$instance_dir/pgdev.manifest"
	msg_info "Instance scaffolding complete at: $instance_dir"
}

cmd_setup() {
	if [ $# -ne 1 ]; then
		msg_error "Usage: pgdev setup <instance_name>"
		return 1
	fi
	local instance_name=$1
	check_instance_exists "$instance_name"
	local instance_dir="$INSTANCES_DIR/$instance_name"

	msg_info "Beginning setup for instance '$instance_name'..."

	# Export environment variables for the blueprint scripts to use.
	export PGDEV_INSTANCE_DIR="$instance_dir"
	export PGDEV_INSTALL_DIR="$instance_dir/install"
	export PGDEV_SRC_DIR="$instance_dir/src"
	mkdir -p "$PGDEV_SRC_DIR"

	# Find and run the blueprint scripts in numerical order.
	# Using find is more robust than parsing ls.
	local components=$(find "$instance_dir" -maxdepth 1 -name "*.configure.sh" | sort)
	if [ -z "$components" ]; then
		msg_error "No '.configure.sh' blueprint scripts found in instance directory."
		return 1
	fi

	for configure_script in $components; do
		local base_name=$(basename "$configure_script" .configure.sh)
		local build_script="$instance_dir/$base_name.build.sh"

		if [ ! -f "$build_script" ]; then
			msg_error "Build script '$build_script' not found for component '$base_name'."
			return 1
		fi

		msg_info "--- Running component: $base_name ---"

		msg_info "Executing configure script: $configure_script"
		bash "$configure_script"

		msg_info "Executing build script: $build_script"
		bash "$build_script"
	done

	msg_info "Setup for instance '$instance_name' is complete."
}

cmd_init() {
	if [ $# -ne 1 ]; then
		msg_error "Usage: pgdev init <instance_name>"
		return 1
	fi
	local instance_name=$1
	check_instance_exists "$instance_name"
	local instance_dir="$INSTANCES_DIR/$instance_name"
	local install_dir="$instance_dir/install"
	local data_dir="$instance_dir/data"

	# --- 1. Initialize the Database Cluster ---
	msg_info "Initializing database cluster..."
	"$install_dir/bin/initdb" -D "$data_dir" --no-locale -E UTF8

	# --- 2. Perform Runtime Configuration ---
	msg_info "Performing runtime configuration..."
	local port=$(find_available_port)
	local postgresql_conf="$data_dir/postgresql.conf"
	local manifest_file="$instance_dir/pgdev.manifest"

	echo "port = $port" >> "$postgresql_conf"

	# Find all unique libraries required for preloading from the manifest,
	# format them into a single comma-separated string, and write to postgresql.conf.
	if [ -f "$manifest_file" ]; then
		# Make sure that we have at least one requires_preload= line in the manifest file
		if grep -q '^requires_preload=' "$manifest_file"; then
			local preload_libs=$(grep '^requires_preload=' "$manifest_file" | cut -d'=' -f2 | awk '!seen[$0]++' | paste -sd, -)
			msg_info "Configuring shared_preload_libraries: $preload_libs"
			echo "shared_preload_libraries = '$preload_libs'" >> "$postgresql_conf"
		fi
	fi

	# --- 3. Write the Final pgdev.conf ---
	msg_info "Writing final instance configuration..."
	local version_string
	version_string=$("$install_dir/bin/pg_config" --version)
	local pgdev_conf="$instance_dir/pgdev.conf"

	echo "port=$port" > "$pgdev_conf"
	echo "version=$version_string" >> "$pgdev_conf"
}

cmd_create() {
	# --- Argument Parsing ---
	if [ $# -ne 2 ]; then
		msg_error "Usage: pgdev create <instance_name> <template_name>"
		return 1
	fi
	local instance_name=$1
	# The remaining arguments are passed directly to cmd_new.

	# --- 1. Scaffold the Instance ---
	cmd_new "$@"

	# --- 2. Build the Instance ---
	cmd_setup "$instance_name"

	# --- 2. Initialize the Cluster ---
	cmd_init "$instance_name"

	# --- 3. Start the Server ---
	cmd_ctl start "$instance_name"

	local port=$(get_instance_config "$instance_name" "port")
	msg_info "Instance '$instance_name' created and running on port $port."
}

cmd_delete() {
	msg_error "Command not available yet"
	msg_info "To fully delete the instance, you can manually run rm -rf ~/pgdev/instances/<name>"
	msg_info "Do not forget to update the default instance if you just deleted it"
}

cmd_ctl() {
	if [ $# -eq 0 ]; then
		msg_error "Usage: pgdev <start|stop|restart|status> [instance_name]"
		return 1
	fi
	local action=$1
	shift

	local instance_name=$(get_instance_name "${1-}") || return 1
	local pg_ctl="$INSTANCES_DIR/$instance_name/install/bin/pg_ctl"
	local data_dir="$INSTANCES_DIR/$instance_name/data"

	case "$action" in
		status)
			if "$pg_ctl" -D "$data_dir" status &>/dev/null; then
				local pid_file="$data_dir/postmaster.pid"
				local pid=$(head -n 1 "$pid_file")
				local port=$(get_instance_config "$instance_name" "port")
				msg_info "Instance '$instance_name' is RUNNING on port $port (PID: $pid)."
			else
				msg_info "Instance '$instance_name' is STOPPED."
			fi
			;;

		start)
			if "$pg_ctl" -D "$data_dir" status &>/dev/null; then
				msg_info "Instance '$instance_name' is already running."
				return 0
			fi

			local port=$(get_instance_config "$instance_name" "port")
			local log_file="$INSTANCES_DIR/$instance_name/postgresql.log"

			msg_info "Starting instance '$instance_name' on port $port..."
			"$pg_ctl" -D "$data_dir" -l "$log_file" start
			;;

		stop)
			if ! "$pg_ctl" -D "$data_dir" status &>/dev/null; then
				msg_info "Instance '$instance_name' is not running."
				return 0
			fi

			msg_info "Stopping instance '$instance_name'..."
			"$pg_ctl" -D "$data_dir" stop
			;;

		restart)
			local port=$(get_instance_config "$instance_name" "port")
			local log_file="$INSTANCES_DIR/$instance_name/postgresql.log"

			msg_info "Restarting instance '$instance_name' on port $port..."
			"$pg_ctl" -D "$data_dir" -l "$log_file" restart
			;;

		*)
			msg_error "Internal error: Unknown ctl action '$action'"
			return 1
			;;
	esac
}

cmd_list() {
	# Check if any instances exist to provide a friendlier message if not.
	if [ -z "$(ls -A "$INSTANCES_DIR")" ]; then
		msg_info "No pgdev instances found."
		return 0
	fi

	# Determine the default instance once before the loop.
	local default_instance_name=""
	local pgsql_symlink="$HOME/pgdev/pgsql"
	if [[ -L "$pgsql_symlink" ]]; then
		# Safely resolve the symlink and get the base directory name.
		default_instance_name=$(basename "$(readlink "$pgsql_symlink")")
	fi

	# Print a formatted header for the table.
	echo ""
	printf "%-25s %-10s %-8s %-8s %-s\n" "INSTANCE" "STATUS" "PORT" "PID" "VERSION"
	printf -- '-%.0s' {1..80} # Prints a horizontal line
	echo ""

	# Loop through each directory in the INSTANCES_DIR.
	for instance_dir in "$INSTANCES_DIR"/*; do
		# Skip if it's not a directory (e.g., a file was placed here).
		if [[ ! -d "$instance_dir" ]]; then
			continue
		fi

		local instance_name=$(basename "$instance_dir")
		local conf_file="$instance_dir/pgdev.conf"

		# Skip if the instance is not fully configured.
		if [[ ! -f "$conf_file" ]]; then
			continue
		fi

		# Read configuration details from the instance's pgdev.conf file.
		local port=$(grep '^port=' "$conf_file" | cut -d'=' -f2)
		local version=$(grep '^version=' "$conf_file" | cut -d'=' -f2)
		local data_dir="$instance_dir/data"
		local pg_ctl="$instance_dir/install/bin/pg_ctl"

		# Check the instance's status and get the PID if running.
		local status="STOPPED"
		local pid="-"
		if "$pg_ctl" -D "$data_dir" status &>/dev/null; then
			status="RUNNING"
			pid=$(head -n 1 "$data_dir/postmaster.pid")
		fi

		# Prepare the display name, adding a '*' if it's the default.
		local display_name="$instance_name"
		if [[ "$instance_name" == "$default_instance_name" ]]; then
			display_name="* $instance_name"
		fi

		# Print the formatted row with all the instance's details.
		printf "%-25s %-10s %-8s %-8s %-s\n" "$display_name" "$status" "$port" "$pid" "$version"
	done
	echo ""
}

cmd_switch() {
	# Should never get here
	msg_error "This command should be implemented by the shell wrapper as it needs to modify environment variables"
}

cmd_default() {
	if [ $# -ne 1 ]; then
		msg_error "Usage: pgdev default <instance_name>"
		return 1
	fi
	local instance_name=$1
}

cmd_run_component_script() {
	if [ $# -ne 2 ]; then
		msg_error "Usage: pgdev configure <instance_name> <component_script>"
		return 1
	fi
	local instance_name=$1
	local component_script=$2
	check_instance_exists "$instance_name"
	local instance_dir="$INSTANCES_DIR/$instance_name"

	# Export environment variables for the blueprint scripts to use.
	export PGDEV_INSTANCE_DIR="$instance_dir"
	export PGDEV_INSTALL_DIR="$instance_dir/install"
	export PGDEV_SRC_DIR="$instance_dir/src"
	mkdir -p "$PGDEV_SRC_DIR"

	if [ ! -f "$component_script" ]; then
		msg_error "Script '$component_script' not found for instance '$instance_name'."
		return 1
	fi

	bash "$component_script"
}

cmd_help() {
    # Main header and usage
	echo "pgdev - PostgreSQL Development Environment Manager"
	echo ""
	echo "A tool for creating, managing, and switching between isolated PostgreSQL"
	echo "development environments built from source."
	echo ""
	echo "Usage: pgdev <command> [options]"
	echo ""

    # Using printf for aligned columns. The format string "%-46s %s\n" creates
    # a left-aligned column of 46 characters for the command, followed by the description.

	echo "Instance Creation & Setup:"
	printf "  %-46s %s\n" "create <name> <template_name>" "All-in-one: scaffolds, builds, and starts an instance."
	printf "  %-46s %s\n" "new <name> <template_name>" "Scaffolds a new instance directory from a template."
	printf "  %-46s %s\n" "setup <name>" "Runs configure and build for a scaffolded instance."
	printf "  %-46s %s\n" "delete <name>" "Stops and completely removes an instance."
	echo ""

	echo "Daily Management:"
	printf "  %-46s %s\n" "list" "Lists all instances, their status, port, and version."
	printf "  %-46s %s\n" "start [name]" "Starts an instance. Uses active one if name is omitted."
	printf "  %-46s %s\n" "stop [name]" "Stops a running instance."
	printf "  %-46s %s\n" "restart [name]" "Restarts an instance."
	printf "  %-46s %s\n" "status [name]" "Check the status of an instance."
	echo ""

	echo "Shell Environment:"
	printf "  %-46s %s\n" "switch <name|default|off>" "Activates an instance for the current shell session."
	printf "  %-46s %s\n" "default <name>" "Sets an instance as the default for all new shells."
	echo ""

	echo "Development & Interaction:"
	printf "  %-46s %s\n" "configures <name> <component>" "(Re-)configures a single component within an instance."
	printf "  %-46s %s\n" "build <name> <component>" "(Re-)compiles a single component within an instance."
	printf "  %-46s %s\n" "test <name> <component>" "Runs the test suite for a single component."
	printf "  %-46s %s\n" "psql [name]" "Connects to the instance using psql."
	printf "  %-46s %s\n" "logs [name]" "Tails the main log file for the instance."
	printf "  %-46s %s\n" "conf [name]" "Opens postgresql.conf for the instance using ${EDITOR:-vi}."
	echo ""
}

# --- Main Dispatcher ---
main() {
	# If no command is given, show usage and exit.
	if [[ $# -eq 0 ]]; then
		cmd_help
		exit 1
	fi

	# Get the command and shift the arguments.
	local command="$1"
	shift

	# This case statement is the core router.
	# It calls the appropriate function based on the command.
	case "$command" in
		# Instance Creation & Setup
		create|new|setup|init|delete)
			"cmd_$command" "$@"
			;;

		# Daily Management
		list|ls)
			cmd_list "$@"
			;;
		start|stop|restart|status)
			cmd_ctl "$command" "$@"
			;;

		# Shell Environment
		switch|default)
			"cmd_$command" "$@"
			;;

		# Development & Interaction
		configure|build|test)
			cmd_run_component_script "$@"
			;;
		psql|logs|conf)
			"cmd_$command" "$@"
			;;

		# Help
		help|-h|--help)
			cmd_help
			;;
		*)
			echo "Error: Unknown command '$command'" >&2
			cmd_help
			exit 1
			;;
	esac
}

# --- Execute the script ---
# This passes all script arguments to your main function.
main "$@"
