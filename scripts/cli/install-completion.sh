#!/bin/bash
# ExaPG CLI - Bash-Completion-Installation

# Ausgabefunktionen
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_message() {
  echo -e "${BLUE}[ExaPG]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[ExaPG]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[ExaPG]${NC} $1"
}

print_error() {
  echo -e "${RED}[ExaPG]${NC} $1"
}

# Installationspfad
BASH_COMPLETION_DIR="/etc/bash_completion.d"
USER_COMPLETION_DIR="$HOME/.bash_completion.d"

# Bash-Completion-Skript
generate_completion_script() {
  cat <<'EOT'
# ExaPG CLI Bash-Completion
_exapg_cli_completions() {
  local cur prev words cword
  _init_completion || return

  # Verfügbare Kommandos
  local commands="1 2 3 4 5 6 7 8 9 s e x q"
  
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "${commands}" -- "$cur"))
    return 0
  fi

  case "$prev" in
    1)
      # Verfügbare Modi für ExaPG Standard
      COMPREPLY=($(compgen -W "1 2" -- "$cur"))
      ;;
    *)
      COMPREPLY=()
      ;;
  esac

  return 0
}

# Registriere die Completion-Funktion für exapg und exapg-cli.sh
complete -F _exapg_cli_completions exapg
complete -F _exapg_cli_completions exapg-cli.sh
EOT
}

# Installiere Bash-Completion
install_completion() {
  if [ -d "$BASH_COMPLETION_DIR" ] && [ -w "$BASH_COMPLETION_DIR" ]; then
    # System-weite Installation
    print_message "Installiere system-weite Bash-Completion für ExaPG CLI..."
    generate_completion_script > "$BASH_COMPLETION_DIR/exapg"
    print_success "Bash-Completion für ExaPG CLI wurde installiert unter $BASH_COMPLETION_DIR/exapg"
  elif [ ! -d "$USER_COMPLETION_DIR" ]; then
    # Erstelle benutzerspezifisches Verzeichnis, falls nicht vorhanden
    print_message "Erstelle Verzeichnis für benutzerspezifische Bash-Completion..."
    mkdir -p "$USER_COMPLETION_DIR"
    # Füge Source-Anweisung zur .bashrc hinzu, falls nicht vorhanden
    if ! grep -q "$USER_COMPLETION_DIR" "$HOME/.bashrc"; then
      print_message "Aktualisiere .bashrc für Bash-Completion..."
      echo "" >> "$HOME/.bashrc"
      echo "# ExaPG CLI Bash-Completion" >> "$HOME/.bashrc"
      echo "if [ -d $USER_COMPLETION_DIR ]; then" >> "$HOME/.bashrc"
      echo "  for f in $USER_COMPLETION_DIR/*; do" >> "$HOME/.bashrc"
      echo "    . \$f" >> "$HOME/.bashrc"
      echo "  done" >> "$HOME/.bashrc"
      echo "fi" >> "$HOME/.bashrc"
    fi
    # Installiere Completion-Skript
    generate_completion_script > "$USER_COMPLETION_DIR/exapg"
    print_success "Bash-Completion für ExaPG CLI wurde installiert unter $USER_COMPLETION_DIR/exapg"
    print_warning "Bitte führen Sie 'source ~/.bashrc' aus, um die Completion zu aktivieren."
  else
    # Installiere in bestehendes benutzerspezifisches Verzeichnis
    print_message "Installiere benutzerspezifische Bash-Completion für ExaPG CLI..."
    generate_completion_script > "$USER_COMPLETION_DIR/exapg"
    print_success "Bash-Completion für ExaPG CLI wurde installiert unter $USER_COMPLETION_DIR/exapg"
    print_warning "Bitte führen Sie 'source ~/.bashrc' aus, um die Completion zu aktivieren."
  fi
}

# Hauptprogramm
install_completion 