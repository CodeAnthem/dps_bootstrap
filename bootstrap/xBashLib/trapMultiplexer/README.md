# Trap Multiplexer

**Stack multiple signal handlers with priorities, execution limits, and exit control**

Prevents trap conflicts between modules by allowing multiple handlers per signal. Configure priorities (higher runs first), set execution limits (one-shot, N-shot), and control exit behavior (exit with first/last code, never exit, or always exit). Drop-in replacement for `trap` that just works.

---

## Table of Contents

- [Basic Trap Usage](#basic-trap-usage)
- [Installation](#installation)
- [Features](#features)
- [Core Concepts](#core-concepts)
- [Public API Reference](#public-api-reference)
- [Bash Signals Reference](#bash-signals-reference)
- [Exit Code Standards](#exit-code-standards)
- [Usage Examples](#usage-examples)
- [Security Considerations](#security-considerations)
- [Debugging](#debugging)
- [Testing](#testing)
- [Requirements](#requirements)

---

## Basic Trap Usage

### Standard Bash Trap

```bash
#!/usr/bin/env bash

# Standard bash trap - only one handler per signal
trap 'rm -rf /tmp/myapp.*' EXIT

# Problem: This REPLACES the previous trap!
trap 'echo "Exiting..."' EXIT  # Previous cleanup is lost!
```

### With Trap Multiplexer

```bash
#!/usr/bin/env bash
source trapMultiplexer.sh

# Multiple handlers for same signal - they ALL execute
trap_named "cleanup" 'rm -rf /tmp/myapp.*' EXIT
trap_named "log" 'echo "Exiting..."' EXIT

# Both handlers will execute in registration order (FIFO)
```

### Using TRAP_LAST_NAME Variable

```bash
#!/usr/bin/env bash
source trapMultiplexer.sh

# Register anonymous trap
trap 'echo "Script exiting"' EXIT

# Configure the trap we just registered using TRAP_LAST_NAME
trap_policy_priority_set "$TRAP_LAST_NAME" 10
trap_policy_limit_set "$TRAP_LAST_NAME" 1

# Useful when sourcing other scripts:
source other_module.sh  # This module uses 'trap ...' internally

# We can still control that trap using TRAP_LAST_NAME from other_module
trap_policy_priority_set "$TRAP_LAST_NAME" -5  # Run last

# ⚠️ Warning: Race condition risk!
# If other_module.sh registers multiple traps or registers them conditionally,
# TRAP_LAST_NAME might not refer to the trap you expect. Use with caution.
```

---

## Installation

```bash
# Source early in your script (before any trap registrations)
source trapMultiplexer.sh
```

**Optional: Custom Output Functions**

You can override output functions *after* sourcing to customize logging:

```bash
source trapMultiplexer.sh

# Now override default output functions
debug() { [[ $DEBUG ]] && echo "[DBG] $*" >&2; }
info() { logger -t mytrap "[INFO] $*"; }
warn() { logger -t mytrap "[WARN] $*"; }
error() { logger -t mytrap "[ERROR] $*"; }
```

The feature provides default implementations, so you don't need to define them beforehand.

---

## Features

| Feature | Description |
|---------|-------------|
| **Named Handlers** | Explicit names or auto-generated for management |
| **Priority Execution** | Higher priority runs first (supports negative values) |
| **Execution Limits** | One-shot, N-shot, or unlimited |
| **Exit Policies** | Control exit behavior: `always`, `once`, `never`, `force` |
| **Suspend/Resume** | Temporarily disable without removing |
| **FIFO Ordering** | Same priority maintains registration order |
| **TRAP_LAST_NAME** | Track last registered handler for dynamic configuration |
| **Eval Safety** | Disable eval to only allow function-based handlers |
| **Debug Utility** | Inspect all registered signals and handlers |
| **Zero Dependencies** | Pure Bash 4.0+, no external requirements |

---

## Core Concepts

### Named Handlers

Every handler has a unique key: `"SIGNAL:handler_name"`

```bash
# Named handler
trap_named "cleanup" 'rm -f /tmp/*' EXIT
# Key: "EXIT:cleanup"

# Anonymous handler (auto-named)
trap 'echo "done"' EXIT
# Key: "EXIT:anonymous_1699564123_1"

# Access last registered name
echo "$TRAP_LAST_NAME"  # Outputs: EXIT:anonymous_1699564123_1
```

### Handler Priority

Handlers execute in **descending priority order** (higher first).

- **Default:** `0`
- **Range:** Any integer (negative allowed)
- **Ties:** FIFO order maintained

```bash
trap_policy_priority_set "EXIT:critical" 100   # First
trap_policy_priority_set "EXIT:normal" 0       # Second
trap_policy_priority_set "EXIT:cleanup" -10    # Last
```

### Execution Limits

- **`0`** - Unlimited (default)
- **`1`** - One-shot (execute once, auto-remove)
- **`N`** - N-shot (execute N times, auto-remove)

```bash
trap_policy_limit_set "SIGUSR1:init" 1     # One-shot
trap_policy_limit_set "SIGUSR1:check" 5    # Run 5 times max
```

### Exit Policies

Controls exit behavior when handlers call `exit()`:

| Policy | Behavior | Use Case |
|--------|----------|----------|
| **`always`** | First `exit()` terminates immediately | Native Bash behavior |
| **`once`** | All handlers run, exit with **last** code | Standard cleanup |
| **`never`** | All handlers run, ignore all `exit()` | Never exit on signal |
| **`force`** | All handlers run, exit with **first** code or `0` | Always exit (e.g., SIGINT) |

```bash
trap_policy_exit_set SIGINT force   # Always exit after SIGINT (default)
trap_policy_exit_set SIGTERM once   # Exit with last handler's code
trap_policy_exit_set SIGHUP never   # Never exit on SIGHUP
```

---

## Public API Reference

### Handler Registration Functions

| Function | Description |
|----------|-------------|
| `trap <code> <signal>...` | Register anonymous handler (auto-named) |
| `trap_named <name> <code> <signal>...` | Register named handler |

**Examples:**
```bash
trap 'echo "cleanup"' EXIT SIGTERM
trap_named "db_close" 'pg_close_conn' EXIT SIGTERM
```

### Exit Policy Functions

| Function | Description |
|----------|-------------|
| `trap_policy_exit_set <signal> <policy>` | Set exit policy: `always\|once\|never\|force` |
| `trap_policy_exit_get <signal>` | Get current exit policy |

**Example:**
```bash
trap_policy_exit_set SIGINT force
policy=$(trap_policy_exit_get SIGINT)
```

### Priority Management Functions

| Function | Description |
|----------|-------------|
| `trap_policy_priority_set <signal:name> <priority>` | Set handler priority (integer) |
| `trap_policy_priority_get <signal:name>` | Get handler priority |

**Example:**
```bash
trap_policy_priority_set "EXIT:cleanup" 10
priority=$(trap_policy_priority_get "EXIT:cleanup")
```

### Execution Limit Functions

| Function | Description |
|----------|-------------|
| `trap_policy_limit_set <signal:name> <limit>` | Set execution limit (0=unlimited) |
| `trap_policy_limit_get <signal:name>` | Get execution limit |

**Example:**
```bash
trap_policy_limit_set "SIGUSR1:init" 1  # One-shot
limit=$(trap_policy_limit_get "SIGUSR1:init")
```

### Query & Inspection Functions

| Function | Description |
|----------|-------------|
| `trap_list <signal>` | List all handler names for signal |
| `trap_handler_info <signal:name>` | Get detailed handler info (code/priority/limit/count) |
| `trap_has <signal>` | Check if signal has any handlers (returns 0=yes, 1=no) |
| `trap_count <signal>` | Count handlers for signal |

**Example:**
```bash
trap_list EXIT
trap_handler_info "EXIT:cleanup"
trap_has SIGUSR1 && echo "Has handlers"
count=$(trap_count SIGUSR1)
```

### Handler Management Functions

| Function | Description |
|----------|-------------|
| `trap_unregister <signal> <name>` | Remove specific handler |
| `trap_clear <signal>` | Remove all handlers for signal |
| `trap_suspend <signal>` | Temporarily disable handlers |
| `trap_resume <signal>` | Re-enable suspended handlers |
| `trap_is_suspended <signal>` | Check if handlers are suspended |

**Example:**
```bash
trap_unregister EXIT "cleanup"
trap_clear SIGUSR1
trap_suspend SIGTERM
trap_resume SIGTERM
```

### Security & Debug Functions

| Function | Description |
|----------|-------------|
| `trap_disable_eval` | Disable eval - only function names allowed (irreversible) |
| `trap_debug` | Display all registered signals and handlers |

**Example:**
```bash
trap_disable_eval  # Security: block inline code, allow only functions
trap_debug         # Show all registered traps with details
```

### Global Variables

| Variable | Description |
|----------|-------------|
| `TRAP_LAST_NAME` | Last registered handler key (e.g., "EXIT:handler_name") |

---

## Bash Signals Reference

### Standard Signals

| Signal | Number | Default Action | Common Use Case |
|--------|--------|----------------|-----------------|
| `SIGHUP` | 1 | Terminate | Terminal disconnect, reload config |
| `SIGINT` | 2 | Terminate | Ctrl+C, interrupt from keyboard |
| `SIGQUIT` | 3 | Core dump | Ctrl+\\, quit with core dump |
| `SIGILL` | 4 | Core dump | Illegal instruction |
| `SIGTRAP` | 5 | Core dump | Trace/breakpoint trap |
| `SIGABRT` | 6 | Core dump | Abort signal from abort() |
| `SIGBUS` | 7 | Core dump | Bus error (bad memory access) |
| `SIGFPE` | 8 | Core dump | Floating point exception |
| `SIGKILL` | 9 | Terminate | **Cannot be caught or ignored** |
| `SIGUSR1` | 10 | Terminate | User-defined signal 1 |
| `SIGSEGV` | 11 | Core dump | Segmentation fault |
| `SIGUSR2` | 12 | Terminate | User-defined signal 2 |
| `SIGPIPE` | 13 | Terminate | Write to closed pipe |
| `SIGALRM` | 14 | Terminate | Timer expiration (alarm) |
| `SIGTERM` | 15 | Terminate | Graceful termination (systemd default) |
| `SIGCHLD` | 17 | Ignore | Child process state change |
| `SIGCONT` | 18 | Continue | Continue if stopped |
| `SIGSTOP` | 19 | Stop | **Cannot be caught or ignored** |
| `SIGTSTP` | 20 | Stop | Ctrl+Z, terminal stop request |
| `SIGTTIN` | 21 | Stop | Background read from tty |
| `SIGTTOU` | 22 | Stop | Background write to tty |
| `SIGURG` | 23 | Ignore | Urgent data on socket |
| `SIGXCPU` | 24 | Core dump | CPU time limit exceeded |
| `SIGXFSZ` | 25 | Core dump | File size limit exceeded |
| `SIGVTALRM` | 26 | Terminate | Virtual timer expired |
| `SIGPROF` | 27 | Terminate | Profiling timer expired |
| `SIGWINCH` | 28 | Ignore | Window size change |
| `SIGIO` | 29 | Terminate | I/O now possible |
| `SIGPWR` | 30 | Terminate | Power failure |
| `SIGSYS` | 31 | Core dump | Bad system call |
| `EXIT` | - | - | Pseudo-signal on shell exit |

**Note:** `SIGKILL` (9) and `SIGSTOP` (19) cannot be trapped.

---

## Exit Code Standards

### Standard Exit Codes

| Code | Meaning | Usage |
|------|---------|-------|
| `0` | Success | Command completed successfully |
| `1` | General error | Catchall for general errors |
| `2` | Misuse of shell builtin | Syntax error, missing keyword |
| `64` | Command line usage error | Invalid arguments |
| `65` | Data format error | Invalid input data |
| `66` | Cannot open input | Input file missing or unreadable |
| `67` | Addressee unknown | User/host does not exist |
| `68` | Host name unknown | Unknown host |
| `69` | Service unavailable | Remote service not available |
| `70` | Internal software error | Programming error |
| `71` | System error | OS error (fork failed, etc.) |
| `72` | Critical OS file missing | Required system file not found |
| `73` | Cannot create output file | Permission or disk space issue |
| `74` | Input/output error | Read/write failed |
| `75` | Temporary failure | Retry might succeed |
| `76` | Remote error in protocol | Protocol error |
| `77` | Permission denied | Insufficient privileges |
| `78` | Configuration error | Invalid configuration |
| `126` | Command cannot execute | Permission denied, not executable |
| `127` | Command not found | Invalid command or PATH issue |
| `128` | Invalid exit code | Exit takes only integer 0-255 |
| `128 + N` | Fatal signal N | Process terminated by signal N |
| `130` | Ctrl+C (SIGINT) | Process interrupted (128 + 2) |
| `137` | SIGKILL | Forcibly killed (128 + 9) |
| `143` | SIGTERM | Terminated (128 + 15) |
| `255` | Exit code out of range | Used exit code > 255 |

**Custom exit codes:** Use `64-113` for application-specific errors (sysexits.h convention).

---

## Usage Examples

### Example 1: Cleanup with Priorities

```bash
# Critical cleanup first
trap_named "kill_child" 'kill $CHILD_PID 2>/dev/null' EXIT
trap_policy_priority_set "EXIT:kill_child" 100

# Then remove temp files
trap_named "cleanup" 'rm -rf /tmp/myapp.*' EXIT
trap_policy_priority_set "EXIT:cleanup" 50

# Finally log
trap_named "log" 'echo "Exited at $(date)"' EXIT
# (default priority 0)
```

### Example 2: One-Shot Initialization

```bash
# Initialize database connection on first signal
trap_named "db_init" 'pg_initialize' SIGUSR1
trap_policy_limit_set "SIGUSR1:db_init" 1

# This handler runs every time
trap_named "db_query" 'pg_execute_query' SIGUSR1
```

### Example 3: Graceful Shutdown

```bash
# Force exit on SIGINT (Ctrl+C)
trap_policy_exit_set SIGINT force
trap_named "interrupt" 'echo "Interrupted"; exit 130' SIGINT

# Graceful shutdown on SIGTERM
trap_policy_exit_set SIGTERM once
trap_named "save_state" 'save_application_state' SIGTERM
trap_named "close_conn" 'close_connections; exit 0' SIGTERM
```

### Example 4: Dynamic Configuration with TRAP_LAST_NAME

```bash
# Register trap dynamically
trap 'cleanup_temp_files' EXIT

# Immediately configure it
trap_policy_priority_set "$TRAP_LAST_NAME" 5
trap_policy_limit_set "$TRAP_LAST_NAME" 1

# Source external module
source external_module.sh
# external_module.sh internally does: trap 'module_cleanup' EXIT

# Configure that external trap
trap_policy_priority_set "$TRAP_LAST_NAME" 10  # Run before our cleanup
```

---

## Security Considerations

### Eval Risk

**⚠️ Warning:** Trap handlers use `eval` for inline code execution, which can execute arbitrary commands.

```bash
# Dangerous: User input in trap (DO NOT DO THIS)
user_input="rm -rf /"
trap "$user_input" EXIT  # DANGEROUS!

# Safer: Use function instead
cleanup_user_data() {
    # Validated, safe cleanup code
    rm -rf "/tmp/user_${USER_ID}"
}
trap cleanup_user_data EXIT
```

### Disabling Eval for Security

If you need to prevent any inline code execution:

```bash
# Disable eval - only function-based handlers will execute
trap_disable_eval

# This will work (function)
my_handler() { echo "safe"; }
trap my_handler EXIT

# This will be IGNORED (inline code)
trap 'echo "dangerous"' SIGUSR1  # Will not execute
```

**Note:** `trap_disable_eval` is **irreversible** (uses `readonly`). Once called, you cannot re-enable eval. Only function-name handlers will execute after this point.

### Best Practices

1. **Prefer functions over inline code** - easier to test and safer
2. **Validate all input** before using in traps
3. **Never use user input** directly in trap handlers
4. **Use trap_disable_eval** in security-critical scripts
5. **Audit handler code** with `trap_debug` before production

---

## Debugging

### Using trap_debug

The `trap_debug` function displays all registered signals, handlers, and their configurations:

```bash
$ trap_debug
╔════════════════════════════════════════════════════════════════════════════════╗
║                         TRAP MULTIPLEXER DEBUG                                 ║
╚════════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Signal: EXIT
  Policy:    once
  Suspended: 0
  Handlers:
    - cleanup
        Priority: 10 | Limit: 0 | Count: 0
        Code: rm -rf /tmp/myapp.*
    - log_exit
        Priority: 0 | Limit: 1 | Count: 0
        Code: echo "Exiting..."

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Signal: SIGINT
  Policy:    force
  Suspended: 0
  Handlers:
    - interrupt_handler
        Priority: 0 | Limit: 0 | Count: 0
        Code: handle_interrupt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Eval disabled: 0
Last registered: EXIT:log_exit
```

### Debugging Tips

**Check handler count:**
```bash
count=$(trap_count EXIT)
echo "EXIT has $count handlers"
```

**Inspect specific handler:**
```bash
trap_handler_info "EXIT:cleanup"
```

**List all handlers:**
```bash
trap_list SIGINT
```

**Check if suspended:**
```bash
trap_is_suspended SIGUSR1 && echo "Suspended"
```

---

## Testing

Run the test suite to verify functionality:

```bash
bash trapMultiplexer_test.sh
```

All **18 tests** (47 assertions) should pass. Tests cover:
- Named and anonymous handlers
- Priority execution order (including negative priorities)
- One-shot and N-shot limits
- All four exit policies (`always`, `once`, `never`, `force`)
- Suspend/resume functionality
- Handler management (list, count, info, unregister, clear)
- TRAP_LAST_NAME variable tracking
- Eval safety feature

---

## Requirements

- **Bash 4.0+** (requires associative arrays)
- **Pure Bash** - no external dependencies

---

## License

Part of DPS Bootstrap - NixOS Deployment System
