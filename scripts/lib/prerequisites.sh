# prerequisites.sh — detect and install Homebrew prerequisites (macOS)

REQUIRED_JQ_VERSION="1.8.1"
REQUIRED_YQ_VERSION="4.53.2"
REQUIRED_PYTHON_MIN="3.10"

# Compare dotted versions: returns 0 if $1 >= $2
_version_ge() {
    have="$1"
    need="$2"
    have_major=$(printf '%s' "$have" | cut -d. -f1)
    have_minor=$(printf '%s' "$have" | cut -d. -f2)
    need_major=$(printf '%s' "$need" | cut -d. -f1)
    need_minor=$(printf '%s' "$need" | cut -d. -f2)

    if [ "$have_major" -gt "$need_major" ]; then
        return 0
    fi
    if [ "$have_major" -lt "$need_major" ]; then
        return 1
    fi
    if [ "$have_minor" -ge "$need_minor" ]; then
        return 0
    fi
    return 1
}

_prereq_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

_prereq_check_node() {
    if _prereq_command_exists node && _prereq_command_exists npx; then
        log_success "Node.js/npx present"
        return 0
    fi
    log_warn "Node.js/npx missing"
    return 1
}

_prereq_check_python() {
    py_cmd=""
    if _prereq_command_exists python3; then
        py_cmd="python3"
    elif _prereq_command_exists python; then
        py_cmd="python"
    fi

    if [ -z "$py_cmd" ]; then
        log_warn "Python 3.10+ missing"
        return 1
    fi

    py_ver=$("$py_cmd" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null) || py_ver=""
    if [ -z "$py_ver" ]; then
        log_warn "Python version could not be determined"
        return 1
    fi

    if _version_ge "$py_ver" "$REQUIRED_PYTHON_MIN"; then
        log_success "Python $py_ver present (>= $REQUIRED_PYTHON_MIN)"
        return 0
    fi

    log_warn "Python version mismatch: installed $py_ver, required >= $REQUIRED_PYTHON_MIN"
    return 1
}

_prereq_check_uv() {
    if _prereq_command_exists uv; then
        log_success "uv present"
        return 0
    fi
    log_warn "uv missing"
    return 1
}

_prereq_check_git() {
    if _prereq_command_exists git; then
        log_success "git present"
        return 0
    fi
    log_warn "git missing"
    return 1
}

_prereq_check_curl() {
    if _prereq_command_exists curl; then
        log_success "curl present"
        return 0
    fi
    log_warn "curl missing"
    return 1
}

_prereq_check_jq() {
    if ! _prereq_command_exists jq; then
        log_warn "jq missing"
        return 1
    fi
    jq_ver=$(jq --version 2>/dev/null | sed 's/jq-//')
    case "$jq_ver" in
        "$REQUIRED_JQ_VERSION") log_success "jq $jq_ver present" ; return 0 ;;
    esac
    log_warn "jq version mismatch: installed $jq_ver, required $REQUIRED_JQ_VERSION"
    return 1
}

_prereq_check_yq() {
    if ! _prereq_command_exists yq; then
        log_warn "yq missing"
        return 1
    fi
    yq_ver=$(yq --version 2>/dev/null | sed 's/yq version //' | cut -d' ' -f1)
    case "$yq_ver" in
        v"$REQUIRED_YQ_VERSION"|"$REQUIRED_YQ_VERSION") log_success "yq $yq_ver present" ; return 0 ;;
    esac
    log_warn "yq version mismatch: installed $yq_ver, required v$REQUIRED_YQ_VERSION"
    return 1
}

prereqs_check_all() {
    missing=0
    _prereq_check_node || missing=$((missing + 1))
    _prereq_check_python || missing=$((missing + 1))
    _prereq_check_uv || missing=$((missing + 1))
    _prereq_check_git || missing=$((missing + 1))
    _prereq_check_curl || missing=$((missing + 1))
    _prereq_check_jq || missing=$((missing + 1))
    _prereq_check_yq || missing=$((missing + 1))

    if [ "$missing" -eq 0 ]; then
        return 0
    fi
    return 1
}

_prereq_brew_install() {
    pkg="$1"
    manual_cmd="$2"

    if ! _prereq_command_exists brew; then
        log_error "Homebrew not found. Install from https://brew.sh then run: $manual_cmd"
        return "$EXIT_PREREQ_INSTALL_FAILED"
    fi

    log_info "Installing $pkg via Homebrew..."
    if brew install "$pkg" >/dev/null 2>&1; then
        log_success "Installed $pkg"
        return 0
    fi

    log_error "Failed to install $pkg"
    log_error "Manual install: $manual_cmd"
    return "$EXIT_PREREQ_INSTALL_FAILED"
}

prereqs_install() {
    install_failed=0
    last_code=0

    _prereq_check_node || {
        _prereq_brew_install "node" "brew install node" || {
            last_code=$?
            install_failed=1
        }
    }

    _prereq_check_python || {
        _prereq_brew_install "python@3.12" "brew install python@3.12" || {
            last_code=$?
            install_failed=1
        }
    }

    _prereq_check_uv || {
        _prereq_brew_install "uv" "brew install uv" || {
            last_code=$?
            install_failed=1
        }
    }

    _prereq_check_git || {
        _prereq_brew_install "git" "brew install git" || {
            last_code=$?
            install_failed=1
        }
    }

    _prereq_check_curl || {
        _prereq_brew_install "curl" "brew install curl" || {
            last_code=$?
            install_failed=1
        }
    }

    _prereq_check_jq || {
        _prereq_brew_install "jq" "brew install jq" || {
            last_code=$?
            install_failed=1
        }
    }

    _prereq_check_yq || {
        _prereq_brew_install "yq" "brew install yq" || {
            last_code=$?
            install_failed=1
        }
    }

    if [ "$install_failed" -ne 0 ]; then
        if [ "$last_code" -eq 0 ]; then
            last_code=$EXIT_PREREQ_INSTALL_FAILED
        fi
        return "$last_code"
    fi

    prereqs_check_all
}
