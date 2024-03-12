# vim:tabstop=2 shiftwidth=2

# This plugin is adapted from oh-my-zsh's dotenv plugin.
# But with more features

# Options

: ${ZSH_DOTENV_VERBOSE:=0}

# Filename of the dotenv file to look for, prompt when enter the directory
: ${ZSH_DOTENV_FILE:=.env}
# Filename of the dotunenv file to look for, prompt when leave the directory (if target directory is out the dotenv's root fir)
: ${ZSH_DOTUNENV_FILE:=.unenv}


# Path to the file containing allowed paths
: ${ZSH_DOTENV_ALLOWED_LIST:="${ZSH_CACHE_DIR:-$ZSH/cache}/dotenv-allowed.list"}
: ${ZSH_DOTENV_DISALLOWED_LIST:="${ZSH_CACHE_DIR:-$ZSH/cache}/dotenv-disallowed.list"}

# List of sourced env root directories
(( ${+ZSH_DOTENV_SOURCED_DIR} )) || {
  declare -ga ZSH_DOTENV_SOURCED_DIR
}



## Functions

function __dotenv_confirm_test_and_source_a_file() {
  # confirm
  if [[ "$ZSH_DOTENV_PROMPT" != false ]]; then
    local confirmation

    # make sure there is an (dis-)allowed file
    touch "$ZSH_DOTENV_ALLOWED_LIST"
    touch "$ZSH_DOTENV_DISALLOWED_LIST"

    # early return if disallowed
    if command grep -Fx -q "$1" "$ZSH_DOTENV_DISALLOWED_LIST" &>/dev/null; then
      return 2
    fi

    # check if current directory's .env file is allowed or ask for confirmation
    if ! command grep -Fx -q "$1" "$ZSH_DOTENV_ALLOWED_LIST" &>/dev/null; then
      # get cursor column and print new line before prompt if not at line beginning
      local column
      echo -ne "\e[6n" > /dev/tty
      read -t 1 -s -d R column < /dev/tty
      column="${column##*\[*;}"
      [[ $column -eq 1 ]] || echo

      # print same-line prompt and output newline character if necessary
      echo -n "dotenv: found '$1' file. Source it? ([Y]es/[n]o/[a]lways/n[e]ver) "
      read -k 1 confirmation
      [[ "$confirmation" = $'\n' ]] || echo

      # check input
      case "$confirmation" in
        [nN]) return 3;;
        [aA]) echo "$1" >> "$ZSH_DOTENV_ALLOWED_LIST" ;;
        [eE]) echo "$1" >> "$ZSH_DOTENV_DISALLOWED_LIST"; return 3;;
        *) ;; # interpret anything else as a yes
      esac
    fi
  fi
  # test file syntax
  zsh -fn "$1" || {
    echo "dotenv: error when sourcing '$1' file" >&2
    return 1
  }
  # source
  setopt localoptions allexport
  source "$1"
  return 0
}

function __dotenv_unsource_if_leave_a_sourced_dir() {
  local dirpath="${PWD:A}"
  for i in {1..$#ZSH_DOTENV_SOURCED_DIR}; do
    local sourced_dir="${ZSH_DOTENV_SOURCED_DIR[$i]}"
    if [[ ! -z $sourced_dir ]] && [[ ! "$dirpath/" =~ "$sourced_dir/" ]]; then
      # leave sourced dir
      if [[ -f "$sourced_dir/$ZSH_DOTUNENV_FILE" ]]; then
        if (( $ZSH_DOTENV_VERBOSE )); then
          echo "dotenv: you're gonna leave $sourced_dir with unenv file." >&2
        fi
        __dotenv_confirm_test_and_source_a_file "$sourced_dir/$ZSH_DOTUNENV_FILE" && {
          # unset "ZSH_DOTENV_SOURCED_DIR[$i]"
        }
      fi
      unset "ZSH_DOTENV_SOURCED_DIR[$i]"
    fi
  done
}

function __dotenv_source_if_enter_a_dir() {
  local dirpath="${PWD:A}"
  if [[ -f "$dirpath/$ZSH_DOTENV_FILE" ]]; then
    if (($ZSH_DOTENV_SOURCED_DIR[(Ie)$dirpath])); then
      if (( $ZSH_DOTENV_VERBOSE )); then
        echo "dotenv: $dirpath with env file already sourced." >&2
      fi
      return
    fi
    if (( $ZSH_DOTENV_VERBOSE )); then
      echo "dotenv: you're gonna enter $dirpath with env file." >&2
    fi
    __dotenv_confirm_test_and_source_a_file "$dirpath/$ZSH_DOTENV_FILE" && {
      # if [[ -f "$dirpath/$ZSH_DOTUNENV_FILE" ]]; then
        ZSH_DOTENV_SOURCED_DIR+=("$dirpath")
      # fi
    }
  fi
}

function source_env() {
  __dotenv_unsource_if_leave_a_sourced_dir
  __dotenv_source_if_enter_a_dir
}

autoload -U add-zsh-hook
add-zsh-hook chpwd source_env

