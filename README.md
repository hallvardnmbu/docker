<img src="window.jpg" style="width: 100%;"></img>

# doc

A simple Rust CLI tool to manage language-specific Docker Compose environments.

**Note:** to use the tool, first follow the [build instructions](#build-instructions).

## Features

- Run `build`, `start`, `shell`, `stop`, `clean`, and `logs` for any language subdirectory containing a `docker-compose.yml`.
- Forwards extra arguments to `docker-compose`.
- Always uses the correct compose file for the specified language.
- Remembers your project root after running `doc setup`.

## Usage

```
doc <command> [language] [extra arguments]
```

### First time setup

Run this once to set your project root (where your language subdirectories are):

```
doc setup
```

You will be prompted for the absolute path to your project root. This will be saved for future use.

### Commands

- `doc list` — List available language subdirectories
- `doc build <language>` — Build the docker image for a language
- `doc start <language>` — Start the container for a language
- `doc shell <language>` — Open a shell in the container for a language
- `doc stop <language>` — Stop the container for a language
- `doc clean <language>` — Clean up containers, images, and volumes for a language
- `doc logs <language>` — Show logs for a language

You can pass extra arguments to docker-compose after the language name, e.g.:

```
doc logs python -f
doc start javascript --service playground-javascript
```

You can override the project root for a single command with `--root <path>`.

## Build instructions

1. Make sure you have [Rust](https://www.rust-lang.org/tools/install) installed.
2. Open a terminal in this directory.
3. Build the CLI tool:

   ```sh
   cargo build --release
   ```

4. The binary will be at `target/release/doc.exe` (Windows) or `target/release/doc` (Linux/macOS).

### Adding the CLI to your PATH

> **Note:** No program can permanently set your PATH for you. You must do this step yourself.

#### Windows

- To use `doc` from any terminal, add the build directory to your PATH:

  - **Temporary (for current session):**
    ```powershell
    $env:PATH += ";$(Resolve-Path .\target\release)"
    ```
  - **Permanent (for all sessions):**
    - Open System Properties → Environment Variables.
    - Edit the `PATH` variable and add the full path to your `target\release` directory (e.g., `C:\Users\YourName\Code\docker\target\release`).
    - Or, copy `doc.exe` to a directory already in your PATH (like `C:\Windows\System32`).

#### Linux/macOS

- To use `doc` from any terminal, add the build directory to your PATH:

  - **Temporary (for current session):**
    ```sh
    export PATH="$PWD/target/release:$PATH"
    ```
  - **Permanent (for all sessions):**
    - Add this line to your `~/.bashrc`, `~/.zshrc`, or `~/.profile`:
      ```sh
      export PATH="/absolute/path/to/your/project/target/release:$PATH"
      ```
    - Or, copy `doc` to `/usr/local/bin`:
      ```sh
      sudo cp target/release/doc /usr/local/bin/
      ```

### Requirements

- Docker and Docker Compose must be installed and available in your system `PATH`.