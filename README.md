<img src="window.jpg" style="width: 100%;"></img>

# doc

A simple Rust CLI tool to manage Docker Compose environments with VPN support.

## Quick Start

1. **Build the tool:**

    ```sh
    cargo build --release
    ```

2. **Credentials:**

    Copy all `.env.example` to `.env` and fill them in.

3. **Paths:**

    Run `echo "/absolute/path/to/this/repository/root" >> ~/.config/doc.conf`.

4. **Start services:**

    ```sh
    ./target/release/doc start <CONTAINER>
    ```

    Where `<CONTAINER>` is one of those displayed in `doc list`.

## Commands

```sh
doc list                         # List available containers
doc run <CONTAINER> <cmd> ...    # Run a command in a container, stopping it afterwards
doc build <CONTAINER>            # Build the container
doc start <CONTAINER>            # Start the container
doc shell <CONTAINER>            # Enter container shell
doc status <CONTAINER>           # Check container and VPN status
doc test <CONTAINER>             # Test container VPN status
doc stop <CONTAINER>             # Stop the container
doc logs <CONTAINER>             # View logs
doc clean <CONTAINER>            # Clean up container
```

## Requirements

- Docker and Docker Compose
- NordVPN account (service credentials)
- Rust (for building CLI tool)
