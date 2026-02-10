# Fluffy

NixOS flake configuration for the fluffy server.

## Development

Enter dev shell: `nix develop`

Available scripts:
- `format` - Format all Nix files
- `lint` - Check for issues (nixf-diagnose, statix, deadnix)
- `fix` - Auto-fix linting issues and format

## Naming Conventions

All names in Nix code must follow:
- **Local let bindings, function args**: camelCase
- **Package names**: kebab-case
- **NixOS options**: kebab-case

## Project Structure

- `flake.nix` - Flake definition with devShell and NixOS configurations
- `configuration.nix` - Main NixOS configuration
- `modules/` - NixOS modules
- `containers/` - Container definitions (quadlet-nix)
- `scripts.nix` - Development scripts (format, lint, fix)
