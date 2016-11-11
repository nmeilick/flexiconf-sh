# -- Setup global variables ---------------------------------------------------
FC_NEWLINE='
'
FC_DEFAULT_IFS="	 $FC_NEWLINE"

FC_SEP="	"

FC_IDX_TYPE=1
FC_IDX_SOURCE=2
FC_IDX_SECTION=3
FC_IDX_ID=4
FC_IDX_PARAMETER=5
FC_IDX_VALUE=6
FC_IDX_LAST=$FC_IDX_VALUE

# Workaround for vim syntax highlighting issue
FC_DQUOTE='"'
FC_SQUOTE="'"

# Variables controlling error handling
FC_ERROR_STDERR=1
FC_ERROR_FILE=''
FC_ERROR_STRIPFUNC=0
FC_ERROR_FILTER=''
FC_ERROR_PREFIX=''
FC_ERROR_DATE=0
if date --help 2>&1 | grep -q %N; then
  FC_ERROR_DATE_FORMAT='[%Y-%m-%d %H:%M:%S.%03N]'
else
  FC_ERROR_DATE_FORMAT='[%Y-%m-%d %H:%M:%S]'
fi

# -- Error handling -----------------------------------------------------------

# Setup the error handler
FC_SetupErrorHandler()
{
  local func="FC_SetupErrorHandler"

  local end_of_options=0
  local arg

  while [ $# -gt 0 ]; do
    if [ $end_of_options = 1 ]; then
      :
    else
      case "$1" in
        --)
          end_of_options=1 ;;
        -r|--reset)
          FC_ERROR_STDERR=1
          FC_ERROR_FILE=''
          FC_ERROR_STRIPFUNC=0
          FC_ERROR_FILTER=''
          FC_ERROR_DATE=0
          FC_ERROR_DATE_FORMAT='[%Y-%m-%d %H:%M:%S]'
          ;;
        -e|--stderr)
          FC_ERROR_STDERR=1
          ;;
        -E|--no-stderr)
          FC_ERROR_STDERR=0
          ;;
        -f|--file|--file=*)
          FC_NeedArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2"  && shift

          FC_ERROR_FILE="$arg"
          ;;
        -s|--strip-func)
          FC_ERROR_STRIPFUNC=1
          ;;
        -S|--no-strip-func)
          FC_ERROR_STRIPFUNC=0
          ;;
        -F|--filter|--filter=*)
          FC_NeedArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2"  && shift

          FC_ERROR_FILTER="$arg"
          ;;
        -p|--prefix|--prefix=*)
          FC_NeedArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2"  && shift

          FC_ERROR_PREFIX="$arg"
          ;;
        -d|--date)
          FC_ERROR_DATE=1
          ;;
        -D|--no-date)
          FC_ERROR_DATE=0
          ;;
        --data-format|--date-format=*)
          FC_NeedArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2"  && shift

          FC_ERROR_DATE_FORMAT="$arg"
          ;;
        -h|--help)
          echo "Syntax: FC_SetupErrorHandler [OPTIONS]"
          echo
          echo "Valid options:"
          echo "   -r, --reset               Reset options to their default (should be first argument)"
          echo
          echo "   -e, --stderr              Log errors to stderr"
          echo "   -E, --no-stderr           Do not log errors to stderr"
          echo "   -f, --file FILE           Log errors to this file (empty = disabled)"
          echo
          echo "   -s, --strip-func          Strip function name from error messages"
          echo "   -S, --no-strip-func       Do not strip function names from error messages"
          echo
          echo "   -F, --filter FUNC         Function filtering the error message"
          echo
          echo "   -p, --prefix TEXT         Prepend the given text"
          echo "   -d, --date                Prepend the current date"
          echo "   -D, --no-date             Do not Prepend the current date"
          echo "       --date-format TEXT    Format string to format date"
          echo
          return 0
          ;;
        -*)
          FC_LogError "$func: Invalid option: $1"
          return 1 ;;
        *)
          if [ $url_was_set = 1 ]; then
            FC_LogError "$func: More than one URL specified: '$1'"
            return 1
          fi
          url="$1" url_was_set=1 ;;
      esac
    fi
    shift
  done
}

FC_LogError()
{
  local error="$*"
  local OIFS="$IFS"

  IFS="$FC_DEFAULT_IFS"

  if [ "$FC_ERROR_STRIPFUNC" = 1 ]; then
    error=$(echo "$error" | sed -r 's/^FC_[A-Za-z0-9]+: //')
  fi

  if [ -n "$FC_ERROR_FILTER" ]; then
    error=$($FC_ERROR_FILTER "$error")
  fi

  if [ -z "$error" ]; then
    IFS="$OIFS"
    return 0
  fi

  error="${FC_ERROR_PREFIX}${error}"

  if [ "$FC_ERROR_DATE" = 1 -a -n "$FC_ERROR_DATE_FORMAT" ]; then
    if date=$(date +"$FC_ERROR_DATE_FORMAT"); then
      error="${date} ${error}"
    fi
  fi

  if [ "$FC_ERROR_STDERR" = 1 ]; then
    echo "$error" 1>&2
  fi

  if [ -n "$FC_ERROR_FILE" ]; then
    echo "$error" >>"$FC_ERROR_FILE"
  fi
  IFS="$OIFS"
}


# -- Helper functions ---------------------------------------------------------

# Iterate over tokens in $1 that are separated by $2 (newline if empty) and execute
# the command in $3...$# with the respective token as argument.
FC_Each()
{
  local tokens="$1"
  local sep="${2:-$FC_NEWLINE}"
  local OIFS="$IFS"
  local ent
  shift 2

  IFS="$sep"
  for ent in $tokens; do
    IFS="$OIFS"
    "$@" "$ent"
  done
  IFS="$OIFS"
}

# Escape text for safe use as a shell parameter
FC_EscapeShell() {
  echo "$*" | sed -e "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

# Escape all space characters by prefixing them with backslash
FC_EscapeSpace() {
  echo "$*" | sed -r 's/ /\\ /g'
}

# Remove surrounding quotation characters (one level)
FC_RemoveQuotes() {
  local text="$1"

  case "$text" in
    $FC_DQUOTE*)
      text="${text#\"}" # Remove leading double quote
      text="${text%\"}" # Remove trailing double quote
      ;;
    $FC_SQUOTE*)
      text="${text#\'}" # Remove leading single quote
      text="${text%\'}" # Remove trailing single quote
      ;;
  esac
  echo "$text"
}

# Remove duplicate lines in unsorted data (case insensitively)
FC_Unique() {
  awk '!seen[tolower($0)]++'
}

# If $1 is a option in the format --option=..., set 'arg' to the
# option value and return true, otherwise set arg empty and return
# false.
FC_GetOptionArg() {
  case "$1" in
    ?*=*)
      arg="${1#*=}"
      return 0
      ;;
    *)
      arg=''
      return 1
  esac
}

# Return true if the argument is a option in the format --option=...
FC_HasArg() {
  case "$1" in
    ?*=*) return 0 ;;
    *) [ $# -gt 1 ] ;;
  esac
}

# Return true if the first argument is a option in the format --option=...
# with a non-empty value or if is there is more than one argument and the
# second one is non-empty.
FC_HasNonEmptyArg() {
  case "$1" in
    ?*=*) [ -n "${1#*=}" ] ;;
    *) [ $# -gt 1 -a -n "$2" ] ;;
  esac
}

# Return true if there is an option with argument in $2..$3, otherwise
# log an error with the given prefix ($1) and return false.
FC_NeedArg() {
  local prefix="$1"
  shift

  if FC_HasArg "$@"; then
    return 0
  else
    FC_LogError "$prefix: Argument missing: ${1%%=*}"
    return 1
  fi
}

# Return true if there is an option with non-empty argument in $2..$3,
# otherwise log an error with the given prefix ($1) and return false.
FC_NeedNonEmptyArg() {
  local prefix="$1"
  shift

  if FC_NeedArg "$prefix" "$@"; then
    if FC_HasNonEmptyArg "$@"; then
      return 0
    else
      FC_LogError "$prefix: Argument must not be empty for option ${1%%=*}"
      return 1
    fi
  else
    return 1
  fi
}

# Load the given URL and return the text
FC_GetURL() {
  local func='FC_GetURL'

  local OIFS="$IFS"

  local end_of_options=0
  local arg=''

  local url=''
  local url_was_set=0
  local client_cert=''
  local ca_file=''
  local ca_dir=''

  while [ $# -gt 0 ]; do
    if [ $end_of_options = 1 ]; then
      if [ $url_was_set = 1 ]; then
        FC_LogError "$func: More than one URL specified: '$1'"
        return 1
      fi
      url="$1" url_was_set=1
    else
      case "$1" in
        --)
          end_of_options=1 ;;
        -u|--url|--url=*)
          FC_NeedNonEmptyArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2"  && shift

          if [ $url_was_set = 1 ]; then
            FC_LogError "$func: More than one URL specified: '$arg'"
            return 1
          fi

          url="$arg" url_was_set=1
          ;;
         --client-cert|--client-cert=*)
          FC_NeedNonEmptyArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2" && shift

          if [ ! -f "$arg" ]; then
            FC_LogError "$func: Client certificate file does not exist: $arg"
            return 1
          fi
          client_cert="$arg"
          ;;
         --ca-file|--ca-file=*)
          FC_NeedNonEmptyArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2" && shift

          if [ ! -f "$arg" ]; then
            FC_LogError "$func: CA file does not exist: $arg"
            return 1
          fi
          ca_file="$arg" ;;
         --ca-dir|--ca-dir=*)
          FC_NeedNonEmptyArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2" && shift

          if [ ! -d "$arg" ]; then
            FC_LogError "$func: CA dir does not exist: $arg"
            return 1
          fi
          ca_dir="$arg"
          ;;
        -h|--help)
          echo "Syntax: FC_GetURL [OPTIONS] [URL]"
          echo
          echo "Valid options:"
          echo "   -u, --url                 URL to get"
          echo "       --client-cert FILE    File containing PEM encoded client certificate and private"
          echo "                             key to authenticate against the server"
          echo "       --ca-file FILE        File containing PEM encoded CA certificates for verification"
          echo "       --ca-dir DIR          Directory containing PEM encoded CA certificates for verification"
          echo
          echo "The URL can be also given as a single non-option argument."
          echo
          echo "If neither --ca-file nor --ca-dir is used, the server's key will not be verified."
          echo
          return 0
          ;;
        -*)
          FC_LogError "$func: Invalid option: $1"
          return 1 ;;
        *)
          if [ $url_was_set = 1 ]; then
            FC_LogError "$func: More than one URL specified: '$1'"
            return 1
          fi
          url="$1" url_was_set=1 ;;
      esac
    fi
    shift
  done

  if [ $url_was_set = 0 ]; then
    FC_LogError "$func: Please specify a --url"
    return 1
  fi
  if [ -z "$url" ]; then
    FC_LogError "$func: Empty URL specified"
    return 1
  fi

  local text=''
  local args=''
  local msg=''

  if type curl >/dev/null 2>&1; then
    args="${DEFAULT_CURL_ARGS:--f -s -S --max-time 10}"
    if [ -n "$client_cert" ]; then
      args="$args --cert $client_cert"
    fi
    if [ -n "$ca_file" ]; then
      args="$args --cacert $ca_file"
    fi
    if [ -n "$ca_dir" ]; then
      args="$args --capath $ca_dir"
    fi
    if [ -z "$ca_file" -a -z "$ca_dir" ]; then
      args="$args --insecure"
    fi

    IFS="$FC_DEFAULT_IFS"
    if text=$(curl $args "$url"); then
      echo "$text"
      IFS="$OIFS"
      return 0
    else
      FC_LogError "$func: Loading URL failed: $url: curl exited with $?"
      IFS="$OIFS"
      return 1
    fi
  elif type wget >/dev/null 2>&1; then
    args="${DEFAULT_WGET_ARGS:---timeout=10 -t1}"
    if [ -n "$client_cert" ]; then
      args="$args --certificate $client_cert"
    fi
    if [ -n "$ca_file" ]; then
      args="$args --ca-certificate $ca_file"
    fi
    if [ -n "$ca_dir" ]; then
      args="$args --ca-directory $ca_dir"
    fi
    if [ -z "$ca_file" -a -z "$ca_dir" ]; then
      args="$args --no-check-certificate"
    fi

    IFS="$FC_DEFAULT_IFS"
    if text=$(wget -O- $args "$url"); then
      echo "$text"
      IFS="$OIFS"
      return 0
    else
      case $? in
        1) msg='Generic error' ;;
        2) msg='Parse error' ;;
        3) msg='File I/O error' ;;
        4) msg='Network failure' ;;
        5) msg='SSL verification failed' ;;
        6) msg='Authentication failed' ;;
        7) msg='Protocol error' ;;
        8) msg='Server returned error' ;;
        *) msg="Unknown error ($?)" ;;
      esac
      FC_LogError "$func: Loading URL failed: $url: $msg"
      IFS="$OIFS"
      return 1
    fi
  else
    FC_LogError "$func: Cannot load URL: $url: Neither curl nor wget found!"
    return 1
  fi
}

# Read the given file and return it on stdout. If the file is a
# http, https or ftp URL, retrieve the file via FC_GetURL.
FC_ReadFile() {
  local func="FC_ReadFile"

  local file="$1"

  case "$file" in
    *${FC_NEWLINE}*|${FC_SEP}*)
      FC_LogError "$func: Unsupported character in filename: $file"
      return 1
      ;;
    http://*|https://*|ftp://*)
      if FC_GetURL "$file"; then
        return 0
      else
        return 1
      fi
      ;;
    -)
      if [ -t 0 ]; then
        FC_LogError "$func: Not reading data from terminal"
        return 1
      fi
      cat
      ;;
    *)
      if [ -f "$file" ]; then
        if cat "$file"; then
          return 0
        else
          return 1
        fi
      else
        FC_LogError "$func: File does not exist: $file"
        return 1
      fi
      ;;
  esac
}

# Join lines ending with the continuation character (backslash).
# Lines are normalized first (tabs replaces by spaces, leading
# and trailing space removed, etc.). The output lines are prepended
# by the given filename and the logical line number, followed by tab.
FC_JoinLines()
{
  local text="$1"
  local file="$2"
  local source="$file"
  local is_joined=""
  local joined=""

  if [ "$source" = - ]; then
    source='STDIN'
  fi

  # Note: A join that is open at the end of the file will be ignored
  echo "$text" | sed -r \
    -e 's/\t/ /g' \
    -e 's/(^\s+|\s+$|<0d>)//g' \
    -e 's/^\[+\s*/[/' \
    -e 's/\s*\]+$/]/' \
    -e 's/([^ =]+)[ =]+/\1 /' \
  | while read line; do
    n=$((n+1))
    case "$line" in
      *\\)
        joined="${joined}${line%\\}"
        if [ -z "$is_joined" ]; then
          is_joined="$n"
        fi
        ;;
      *)
        if [ -z "$is_joined" ]; then
          echo "${source}:${n}	${line}"
        else
          echo "${source}:${is_joined}	${joined}${line}"
          joined=""
          is_joined=
        fi
    esac
  done | sed -r -e "s/\t\s+/\t/"
}

# Resolve include statements in the configuration.
# Examples:
#
# Include a specific file. The Path can be absolute or relative
# to the including file's directory. If a file does not exist,
# an error is printed. If the path points to a directory, all
# files in it matching *.conf are included:
#
#   @include somefile
#   @include /some/file
#   @include ../some/directory
#
# Include files via glob pattern. The list of matching files is sorted
# alphabetically and then filtered by removing entries starting with
# a dot, containing a tilde (~) or ending with .swp, .tmp or .disabled.
#
#   @include /etc/config.d/*.conf
#   @include /etc/config.d/*/*.conf
#
FC_ResolveIncludes()
{
  local func="FC_ResolveIncludes"

  local line
  local source
  local l
  local f
  local cursrc
  local curdir
  local escaped
  local files

  echo "$1" | while read line; do
    source="${line%%	*}"
    l="${line#*	}"

    case "$l" in
      @[iI][nN][cC][lL][uU][dD][eE]*)
        f=$(echo "$l" | cut -d" " -f ${FC_IDX_SOURCE}- | sed -r 's/(^ +| +$)//')
        if [ -n "$f" ]; then
          case "$f" in
            /*|*://*)
              # Already absolute
              ;;
            *)
              cursrc="${source%:*}"
              curdir=$(dirname "$cursrc")
              f="$curdir/$f"
              ;;
          esac

          if [ -d "$f" ]; then
            f="$f/*.conf"
          fi

          case "$f" in
            *\**|*\?*)
              escaped=$(FC_EscapeSpace "$f")
              files=$(sh -c "ls $escaped | sort" 2>/dev/null || true)

              local OIFS="$IFS"
              IFS="$FC_NEWLINE"
              for ent in $files; do
                IFS="$OIFS"
                case "$(basename "$ent")" in
                  .*|*~*|*${FC_NEWLINE}*|${FC_SEP}*|.[sS][wW][pP]|*.[tT][mM][pP]|*.[dD][iI][sS][aA][bB][lL][eE][dD]) ;;
                  *)
                  if [ -f "$ent" ]; then
                    FC_LoadFile "$ent" || true
                  fi
                esac
              done
              IFS="$OIFS"
              ;;
            *)
              if ! FC_LoadFile "$f"; then
                FC_LogError "$func: $source: Include failed: $f"
              fi
              ;;
          esac
        fi
        ;;
      *)
        echo "$line"
        ;;
    esac
  done
}

# Return the given file or URL on stdout after reading it, joining
# lines and resolving includes.
FC_LoadFile()
{
  local file="$1"
  local text=""

  if ! text=$(FC_ReadFile "$file"); then
    return 1
  fi

  if ! text=$(FC_JoinLines "$text" "$file"); then
    return 1
  fi

  if ! text=$(FC_ResolveIncludes "$text"); then
    return 1
  fi

  echo "$text"
}

# Parse the given configuration file
FC_ParseFile()
{
  local func='FC_ParseFile'

  local end_of_options=0
  local arg=''
  local file=''
  local file_was_set=0
  local schemafile=''
  local schema_was_set=0
  local inherit=0

  local schema=''
  local text=''

  while [ $# -gt 0 ]; do
    if [ $end_of_options = 1 ]; then
      if [ $file_was_set = 1 ]; then
        FC_LogError "$func: More than one file or non-option arguments specified: '$1'"
        return 1
      fi
      file="$1" file_was_set=1
    else
      case "$1" in
        --)
          end_of_options=1 ;;
        -i|--inherit)
          inherit=1 ;;
        -f|--file|--file=*)
          FC_NeedNonEmptyArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2" && shift

          if [ $file_was_set = 1 ]; then
            FC_LogError "Error: More than one file is not supported: '$arg'"
            return 1
          fi
          file="$arg" file_was_set=1
          ;;
        -s|--schema|--schema=*)
          FC_NeedNonEmptyArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2" && shift

          if [ $schema_was_set = 1 ]; then
            FC_LogError "Error: More than one schema is not supported: '$arg'"
            return 1
          fi
          schemafile="$arg" schema_was_set=1
          ;;
        -h|--help)
          echo "Syntax: FC_ParseFile [OPTIONS] [FILE]"
          echo
          echo "Valid options:"
          echo "   -f, --file FILE           File to parse (- for stdin)"
          echo "   -s, --schema FILE         File containing the schema"
          echo "   -i, --inherit             Inherit values from base or default sections"
          echo
          echo "The file to parse can be also given as a single non-option argument."
          echo
          return 1
          ;;
        -)
          if [ $file_was_set = 1 ]; then
            FC_LogError "Error: More than one file is not supported: '$1'"
            return 1
          fi
          file="$1" file_was_set=1 ;;
        -*)
          if [ -f "$1" ]; then
            if [ $file_was_set = 1 ]; then
              FC_LogError "Error: More than one file is not supported: '$1'"
              return 1
            fi
            file="$1" file_was_set=1
            shift
            continue
          fi
          FC_LogError "Error: Invalid option: $1"
          return 1 ;;
        *)
          if [ $file_was_set = 1 ]; then
            FC_LogError "Error: More than one file is not supported: '$1'"
            return 1
          fi
          file="$1" file_was_set=1 ;;
      esac
    fi
    shift
  done

  if [ $file_was_set = 0 ]; then
    FC_LogError 'Error: No file was specified!'
    return 1
  fi
  if [ -z "$file" ]; then
    FC_LogError 'Error: Empty file specified!'
    return 1
  fi
  if [ -n "$schemafile" ]; then
    if ! schema=$(FC_ParseFile "$schemafile"); then
      return 1
    fi
  fi

  if ! text=$(FC_LoadFile  "$file"); then
    return 1
  fi

  local source
  local line

  local section=''
  local id=''
  local parameter
  local value

  echo "O${FC_SEP}inherit=${inherit}"

  local OIFS="$IFS"
  IFS="$FC_SEP"
  echo "$text" | while read source line; do
    IFS="$OIFS"
    case "$line" in
      "["*)
        line="${line##\[}"
        line="${line%%\]}"

        section="${line%% *}"
        case "$line" in
          *\ *)
            id="${line#* }"
            id=$(FC_RemoveQuotes "$id")
            ;;
          *)
            id=""
            ;;
        esac
        ;;
      '#'*)
        ;;
      *)
        if [ -n "$line" -a -n "$section" ]; then
          parameter="${line%% *}"
          case "$line" in
            *\ *)
              value="${line#* }"
              value=$(FC_RemoveQuotes "$value")
              ;;
            *)
              value=""
              ;;
          esac

          echo "C${FC_SEP}${source}${FC_SEP}${section}${FC_SEP}${id}${FC_SEP}${parameter}${FC_SEP}${value}"
        fi
    esac
  done
  if [ -n "$schema" ]; then
    echo "$schema" | grep ^C | sed 's/^C/S/'
  fi
  IFS="$OIFS"
}

# Set the schema to
FC_SetSchema() {
  local config="$1"
  local schema="$2"

  echo "$config" | grep -v ^S
  echo "$schema" | grep '^[CS]' | sed 's/^C/S/'
}

# Apply schema. Errors are returned on stdout.
FC_ApplySchema() {
  local config="$1"
  local schema="$2"
  local sn pn id stag ctag p nvals s line
  local need_id prohibit_id inheritance

  if [ -n "$schema" ]; then
    config=$(FC_SetSchema "$config" "$schema")
  else
    schema=$(echo "$config" | grep ^S | sed s/^S/C/)
  fi

  FC_SectionNames "$schema" | while read sn; do
    #if FC_Enabled "$schema" "$sn.NeedID"; then need_id=1; else need_id=0; fi
    #if FC_Enabled "$schema" "$sn.ProhibitID"; then prohibit_id=1; else prohibit_id=0; fi
    #if FC_Enabled "$schema" "$sn.NoInheritance"; then inheritance=0; else inheritance=1; fi
    FC_SectionIds "$schema" "$sn" | while read pn; do
      stag="$sn.$pn"
      FC_SectionIds "$config" "$sn" | while read id; do
        if [ -z "$id" ]; then
          ctag="$sn"
          #if [ "$need_id" = 1 -a "$inheritance" = 0 ]; then
          #  echo "Section '$ctag' has no ID!"
          #  continue
          #fi
        else
          ctag="$sn.$id"
          #if [ "$prohibit_id" = 1 ]; then
          #  echo "Section '$stag' has an ID but should not have one!"
          #  continue
          #fi
        fi
        p=$(FC_Parameter "$config" "$sn.$id.$pn")
        nvals=$(echo "$p"|wc -l)

        s=$(FC_Value "$schema" "$stag.Multiple")
        case "$s" in
          "")
            ;;
          [nN][oO])
            if [ "$nvals" -gt 1 ]; then
              echo "Multiple values set for single value parameter '$pn' in section ${ctag} in..."
              echo "$p" | cut -d"$FC_SEP" -f $FC_IDX_SOURCE | while read line; do
                echo "    $line"
              done
              continue
            fi
            ;;
        esac

        if [ -z "$p" ]; then
          if FC_Enabled "$schema" "$stag.Mandatory"; then
            echo "Mandatory parameter '$pn' not set in section '$ctag'!"
            continue
          fi
        fi
      done
    done
  done
}

# -- Options ------------------------------------------------------------------

# Return the option line from the given config
FC_Options() {
  echo "$1" | head -n1 | grep -E "^O${FC_SEP}"
}

# Return the options from the given config as key=value pair separated by newlines
FC_OptionPairs() {
  FC_Options "$1" | cut -d"$FC_SEP" -f 2- | sed "s/$FC_SEP/\\n/g"
}

# Return a key=value pair for the named option ($2) in the config ($1)
FC_Option() {
  FC_OptionPairs "$1" | grep -i "^$2" | cut -d= -f 2-
}

# Return true if the named option ($2) is enabled in the config ($1),
# i.e., if its value is neither 0 nor empty.
FC_OptionIsSet() {
  case $(FC_Option "$1" "$2") in
    ""|0)
      return 1
      ;;
  esac
  return 0
}


# -- Sections -----------------------------------------------------------------

# Return the section for tag ($2) from the config ($1). If inheritance is enabled,
# also return parent and default section.
FC_Section() {
  local config="$1"
  local tag="$2"

  local section="${tag%%.*}"
  local id="${tag#*.}"

  local options=$(FC_Options "$config")
  local inherit=$(FC_Option "$options" inherit)

  echo "$options"
  if [ "$inherit" = 1 ]; then
    echo "$config" | grep -Ei "^C${FC_SEP}[^${FC_SEP}]+${FC_SEP}(${section}${FC_SEP}${id}|${section}${FC_SEP}|Default)${FC_SEP}"
  else
    echo "$config" | grep -Ei "^C${FC_SEP}[^${FC_SEP}]+${FC_SEP}${section}${FC_SEP}${id}${FC_SEP}"
  fi
}

# Iterate over each section of config ($1) and call $2..$# with the section data
# as last argument.
FC_EachSection() {
  local config="$1"
  shift

  local section
  local id

  FC_SectionNames "$config" | while read section; do
    FC_SectionIds "$config" "$section" | while read id; do
      "$@" "$(FC_Section "$config" "$section.$id")"
    done
  done
}
# Print a list of all section names.
FC_SectionNames() {
  echo "$1" | grep -E "^C${FC_SEP}" | cut -d"$FC_SEP" -f $FC_IDX_SECTION | FC_Unique
}

# Iterate over each section name of config ($1) by calling $2..$# with the section
# name as last argument.
FC_EachSectionName() {
  local config="$1"
  shift
  FC_Each "$(FC_SectionNames "$config")" '' "$@"
}

# Print a list of all section ids for the given section name ($2) in config ($1).
FC_SectionIds() {
  echo "$1" | grep -E "^C${FC_SEP}" | cut -d"$FC_SEP" -f $FC_IDX_SECTION,$FC_IDX_ID | grep -i "^$2	" | cut -d"$FC_SEP" -f 2 | FC_Unique
}

# Iterate over each section id of section name ($1) by calling $2..$# with the section
# id as last argument.
FC_EachSectionId() {
  local config="$1"
  local name="$2"
  shift 2

  FC_Each "$(FC_SectionIds "$config" "$name")" '' "$@"
}

# Print a list of all section tags ($section.$id) in config ($1).
FC_SectionTags() {
  echo "$1" | grep -E "^C${FC_SEP}" | cut -d"$FC_SEP" -f $FC_IDX_SECTION,$FC_IDX_ID | FC_Unique | sed "s/$FC_SEP/./"
}

# Iterate over each section tag of config ($1) by calling $2..$# with the section
# tag as last argument.
FC_EachSectionTag() {
  local config="$1"
  shift

  FC_Each "$(FC_SectionTags "$config")" '' "$@"
}

# -- Parameters ---------------------------------------------------------------
FC_ParameterNames() {
  local tag="$2"

  local section="${tag%%.*}"
  local id="${tag#*.}"

  echo "$1" | grep -E "^C${FC_SEP}" | cut -d"$FC_SEP" -f $FC_IDX_$FC_IDX_SECTION-$FC_IDX_PARAMETER | grep -i "^$section	$id	" | cut -d"$FC_SEP" -f 3 | FC_Unique
}
FC_EachParameterName() {
  local config="$1"
  local tag="$2"
  shift 2
  FC_Each "$(FC_ParameterNames "$config" "$tag")" '' "$@"
}

FC_Parameter() {
  local config="$1"
  local tag="$2"

  local section="${tag%%.*}"
  local tmp="${tag#*.}"
  local id=""
  local param=""
  local text=""
  case "$tmp" in
    *.*) id="${tmp%.*}" ;;
    *) id="" ;;
  esac
  param="${tmp##*.}"

  text=$(echo "$config" | grep -E "C${FC_SEP}" | grep -Fi "	$section	$id	$param	")
  if [ -z "$text" ] && FC_OptionIsSet "$config" inherit; then
    if [ -n "$id" ]; then
      FC_Parameter "$config" "$section.$param"
    else
      case "$section" in
        [dD][eE][fF][aA][uU][lL][tT])
          ;;
        *)
          FC_Parameter "$config" "Default.$param"
          ;;
      esac
    fi
  else
    echo "$text"
  fi
}

FC_FirstParameter() {
  FC_Parameter "$@" | head -n1
}
FC_LastParameter() {
  FC_Parameter "$@" | tail -n1
}

FC_UseParameter()
{
  local config="$1"
  local tag="$2"
  local v=""
  local res=""
  local param_set=0
  local text=$(FC_Parameter "$config" "$tag")

  RAW_VALUE=""
  VALUE=""
  SOURCE=""
  FIRST_VALUE=""
  LAST_VALUE=""
  RAW_VALUES=""
  VALUES=""
  TOKENS=""

  local OIFS="$IFS"
  IFS="$FC_NEWLINE"
  for line in $text; do
    IFS="$OIFS"
    SOURCE="${line%%	*}"
    RAW_VALUE="${line##*	}"

    case "$VALUE" in
      \<*) VALUE=$(FC_ResolveValue "$RAW_VALUE") ;;
        *) VALUE="$RAW_VALUE" ;;
    esac

    if [ "$param_set" = 0 ]; then
      RAW_VALUES="$RAW_VALUE"
      VALUES="$VALUE"
      FIRST_VALUE="$VALUE"
      TOKENS=$(echo "$VALUE" | xargs -d, -n1 | sed -r 's/(^ +| +$)//')
      param_set=1
    else
      RAW_VALUES="${RAW_VALUES}${FC_NEWLINE}${RAW_VALUE}"
      VALUES="${VALUES}${FC_NEWLINE}${VALUE}"
      TOKENS="${TOKENS}${FC_NEWLINE}$(echo "$VALUE" | xargs -d, -n1 | sed -r 's/(^ +| +$)//')"
    fi
    LAST_VALUE="$VALUE"
  done
  IFS="$OIFS"
  TOKENS=$(echo "$TOKENS" | FC_Unique | grep -v '^$')

  [ "$param_set" = 1 ]
}

# -- Values -------------------------------------------------------------------

# Resolve value by checking for indirection operators.
FC_ResolveValue() {
  local value="$1"

  case "$value" in
    \<*)
      v=$(echo "$value" | sed -r -e 's/^<?\s*//g')
      case "$v" in
        [fF][iI][lL][eE]:*)
          res=$(echo "$v" | cut -d: -f 2- | sed -r 's/^\s+//')
          if [ -z "$res" ]; then
            value=''
          else
            value=$(head -n1 "$res")
          fi
          ;;
        [uU][rR][lL]:*)
          res=$(echo "$v" | cut -d: -f 2- | sed -r 's/^\s+//')
          if [ -z "$res" ]; then
            value=''
          else
            if v=$(FC_GetURL "$res"); then
              value=$(echo "$v" | head -n1)
            else
              value=''
              FC_LogError "$source: Loading URL failed: $res"
            fi
          fi
          ;;
        [sS][cC][rR][iI][pP][tT]:*)
          res=$(echo "$v" | cut -d: -f 2- | sed -r 's/^\s+//')
          if [ -z "$res" ]; then
            value=''
          else
            if [ -x "$res" ]; then
              if v=$("$res"); then
                value=$(echo "$v" | head -n1)
              else
                value=''
              fi
            else
              value=''
            fi
          fi
          ;;
        [eE][nN][vV]:*)
          res=$(echo "$v" | cut -d: -f 2- | sed -r 's/^\s+//')
          if [ -z "$res" ]; then
            value=''
          else
            if v=$(printenv "$res"); then
              value=$(echo "$v" | head -n1)
            else
              value=''
            fi
          fi
          ;;
        *:*)
          FC_LogError "$source: Unsupported data source: $v"
          value=''
          ;;
      esac
      ;;
  esac
  echo "$value"
}

FC_RawValues() {
  local v

  if [ -z "$2" ]; then
    echo "$1"
  else
    FC_Parameter "$@"
  fi | cut -d"$FC_SEP" -f $FC_IDX_VALUE
}
FC_EachRawValue()
{
  local config="$1"
  local tag="$2"
  shift 2

  FC_Each "$(FC_RawValues "$config" "$tag")" '' "$@"
}
FC_FirstRawValue()
{
  FC_RawValues "$@" | head -n1
}
FC_LastRawValue()
{
  FC_RawValues "$@" | tail -n1
}
FC_RawValue()
{
  FC_LastRawValue "$@"
}

FC_Values() {
  local v

  FC_RawValues "$@" | while read v; do
    echo "$(FC_ResolveValue "$v")"
  done
}
FC_EachValue()
{
  local config="$1"
  local tag="$2"
  shift 2

  FC_Each "$(FC_Values "$config" "$tag")" '' "$@"
}
FC_FirstValue() {
  FC_ResolveValue "$(FC_FirstRawValue "$@")"
}
FC_LastValue() {
  FC_ResolveValue "$(FC_LastRawValue "$@")"
}
FC_Value() {
  FC_LastValue "$@"
}

# -- Checks -------------------------------------------------------------------

# Return true if the given parameter tag's ($2) value, interpreted as
# boolean, is true. Most common settings (1, true, yes, enabled, ...) are
# supported.
FC_Enabled() {
  case "$(FC_Value "$1" "$2")" in
    [yY]|[yY][eE][sS]|[tT][rR][uU][eE]|[oO][nN])
      return 0
      ;;
  esac
  return 1
}

# Return true if the given parameter tag's ($2) value, interpreted as
# boolean, is false. Most common settings (0, false, no, disabled, ...)
# are supported.
FC_Disabled() {
  case "$(FC_Value "$1" "$2")" in
    [nN]|[nN][oO]|[fF][aA][lL][sS][eE]|[oO][fF][fF])
      return 0
      ;;
  esac
  return 1
}

# Dump the configuration data
FC_Dump() {
  local config="$1"

  FC_SectionNames "$config" | while read n; do
    FC_SectionIds "$config" "$n" | while read i; do
      echo "  Section $n '$i':"
      FC_ParameterNames "$config" "$n.$i" | while read p; do
        if FC_UseParameter "$config" "$n.$i.$p"; then
          #echo "$SOURCE: $n.$i.$p: $VALUE"
          echo "    Parameter: $p"
          echo "      Source: $SOURCE"
          echo "      Value: $VALUE"
          export vn=0
          echo "$VALUES"|while read v; do
            vn=$((vn+1))
            echo "      Value #$vn: $v"
          done
          echo "        Tokens: $TOKENS"
        fi
      done
    done
  done
}

# Set the given configuration data in the environment
FC_SetInEnv() {
  # TODO: Inheritance, index of sections and ids
  local func='FC_SetInEnv'

  local end_of_options=0
  local arg=''
  local config=''
  local config_was_set=0

  local prefix='P_'
  local lowercase=0
  local set_prefix=""
  local evaluate=1
  local clear=yes

  while [ $# -gt 0 ]; do
    if [ $end_of_options = 1 ]; then
      if [ $config_was_set = 1 ]; then
        FC_LogError "$func: Configuration was already set"
        return 1
      fi
      config="$1" config_was_set=1
    else
      case "$1" in
        --)
          end_of_options=1 ;;
        -c|--config|--config=*)
          FC_NeedNonEmptyArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2" && shift

          if [ $config_was_set = 1 ]; then
            FC_LogError "$func: Configuration was already set"
            return 1
          fi
          config="$arg" config_was_set=1
          ;;
        -p|--prefix|--prefix=*)
          FC_NeedNonEmptyArg "$func" "$@" || return 1
          FC_GetOptionArg "$1" || arg="$2" && shift

          case "$arg" in
            [0-9]*)
              FC_LogError "$func: Variable prefix should not start with a digit: $arg"
              return 1
              ;;
          esac
          prefix=$(echo "$arg" | sed -r 's/[^A-Za-z0-9_]/_/g')
          ;;
        -l|--lowercase)
          lowercase=1
          ;;
        -e|--export)
          set_prefix="export "
          ;;
        --text)
          evaluate=0
          ;;
        --clear)
          clear=only
          ;;
        -n|--no-clear)
          clear=no
          ;;
        -h|--help)
          echo "Syntax: FC_SetInEnv [OPTIONS] [CONFIG]"
          echo
          echo "Valid options:"
          echo "   -c, --config TEXT         Configuration data"
          echo "   -p, --prefix TEXT         Prefix to use for variables (Default: '$prefix')"
          echo "   -l, --lowercase           Use lowercase variable name (Default: uppercase)"
          echo "   -e, --export              Mark variables for export to child processes"
          echo "       --text                Do not evaluate and print the command text instead"
          echo "       --clear               Clear variables matching the prefix and return"
          echo "   -n, --no-clear            Do not clear variables before setting new ones"
          echo "   -h, --help                This help"
          echo
          echo "The file to parse can be also given as a single non-option argument."
          echo
          return 1
          ;;
        -*)
          FC_LogError "$func: Invalid option: $1"
          return 1 ;;
        *)
          if [ $config_was_set = 1 ]; then
            FC_LogError "$func: Configuration was already set"
            return 1
          fi
          config="$1" config_was_set=1 ;;
      esac
    fi
    shift
  done

  if [ $config_was_set = 0 ]; then
    FC_LogError "$func: Configuration was not specified"
    return 1
  fi


  text=$(echo "$config" | grep "^C${FC_SEP}" | cut -d"$FC_SEP" -f 3-)

  local section
  local id
  local param
  local value
  local tags=''
  local values=''

  local OIFS="$IFS"
  IFS="$FC_NEWLINE"

  code=$(
    if [ $clear != no ]; then
      if [ -n "$prefix" ]; then
        set | grep -Ei "^$prefix" | grep -E "^[^ =]+=" | cut -d= -f 1 | sed 's/^/unset /'
      fi
    fi

    if [ $clear != only ]; then
      for line in $text; do
        IFS="$FC_DEFAULT_IFS"
        section="${line%%	*}"
        line="${line#*	}"
        id="${line%%	*}"
        line="${line#*	}"
        param="${line%%	*}"
        line="${line#*	}"
        value="${line%%	*}"

        if [ -z "$id" ]; then
          tag="${section}_${param}"
        else
          tag="${section}_${id}_${param}"
        fi

        if [ $lowercase = 1 ]; then
          tag=$(echo "$tag" | tr A-Z a-z | sed -r 's/[^a-z0-9_]/_/g')
        else
          tag=$(echo "$tag" | tr a-z A-Z | sed -r 's/[^A-Z0-9_]/_/g')
        fi
        tag="$prefix$tag"
        case "$tag" in
          [0-9]*) tag="_$tag" ;;
        esac
        value=$(LC_ALL=C echo "$value"|sed -e "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/") #sed -e 's/[^a-zA-Z0-9,._+@%/-]/\\&/g; 1{$s/^$/""/}; 1!s/^/"/; $!s/$/"/')
        echo "$set_prefix$tag=$value"
      done
    fi
  )
  IFS="$OIFS"
  if [ $evaluate = 1 ]; then
    eval "$code"
  else
    echo "$code"
  fi
}
