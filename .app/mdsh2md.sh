#!/bin/bash

# sc0ttj
# Based on an example script by Stéphane Chazelas.

if [ ! "$1" ] || [ "$1" = "-h" ] || [ "$1" = "-help" ] || [ "$1" = "--help" ];then
  cat << HELP_MSG

 Process .mdsh files, outputting valid Markdown files (.md)

 Usage:  mdsh2md path/to/file.mdsh # will output path/to/file.md

HELP_MSG
  exit
fi

# load the local config file
[ -f .site_config ] && source .site_config

# define run-time vars used by this program
prev_line=none
line_is_bash=false
line_was_bash=false
multi_line_string=false
was_multi_line_string=false
command=''
command_line_count=0

if [ ! -f "$1" ] && [ "$1" != "-all" ];then
  mkdir -p "$(dirname "$1")"
  touch "$1"
fi

if [ ! -f "$1" ];then
  exit 1
fi


# get contents only (ignoring meta/front matter)
mdsh_contents="$(cat "$1")"     # get file contents
md_body="${mdsh_contents#*---}" # remove everything before (and including) ---

# write markdown body to temp file
echo "$md_body" > /tmp/markdown

# we will read the file line by line and process it...

#  IFS=  preserve whitespace
#  -e    use readline
#  -r    dont escape backslashes include them as literals chars
while IFS= read -r line
do

  # if line starts with ``` we know it's a markdown line, not part of a bash sub-shell
  [ "$(echo "$line" | grep '^```')" != "" ] && line_is_bash=false

  # if line starts with ~~~ we know it's a markdown line, not part of a bash sub-shell
  [ "$(echo "$line" | grep '^~~~')" != "" ] && line_is_bash=false

  # if the line contains $( then the user is starting a bash sub-shell on this line
  [ "$(echo "$line" | grep -m1 '$(')" != "" ] && line_is_bash=true

  # if the line is not bash, then it's also not a multi line string
  #if [ "$line_is_bash" = false ];then
  #  multi_line_string=false
  #fi

  # if the previous last (one before last entered) was part of a multi-line string,
  # then this line probably is too, and so it's part of a bash command
  [ "$was_multi_line_string" = true ] && line_was_bash=true

  # the the line given was bash, not markdown, we need to interpret it
  if [ "$line_is_bash" = true ];then

    # count the bumber of double quotes, and chck if that number is even
    quote_count=$(echo "$line" | tr -cd '"' | wc -c)
    quote_count_is_even=$(( ${quote_count} %2 ))

    # if $line has quotes, and an odd number of them, we moved in/out of a string
    if [ $quote_count -gt 0 ] && [ $quote_count_is_even -ne 0 ];then
      # toggle whether in a string or not
      if [ "$multi_line_string" = true ];then
        multi_line_string=false    # toggle it
      else
        multi_line_string=true     # toggle it
      fi
    fi

    # while we are in a bash sub-shell, lets save each line in the $command var
    if [ "$command" = "" ];then
      command="$line"
    else
      command="$command\n$line"
    fi
    command_line_count=$(($command_line_count + 1))

    # check if the command has a closing parenthesis ) - cos then we might be ending the sub-shell
    subshell_has_ended="$(echo "$command" | grep -Eq ')' && echo true || echo false)"

    # if line is part of a multi string, it's been saved into $command, so skip
    if [ "$multi_line_string" = true ];then

      line_is_bash=true

    # else if we detected the end of a sub-shell, lets evaluate it, get its output
    # and then save that to our markdown file, instead of the bash commands themselves
    elif [ "$subshell_has_ended"  = true ];then

      # strip any leading chars up to the sub-shell invocation '$(' and
      # strip any chars after the sub-shell, and
      # keep only the command
      pre_text="$(echo "$command" | sed -e 's/$(.*//' -e 's/)$//')"
      post_text="$(echo "$command" | sed 's/.*$(.*)//g')"
      if [ "$pre_text"  != "" ] || [ "$post_text"  != "" ];then
        command="$(echo "$command" | sed -e "s/^$pre_text//g" -e "s/$post_text//")"
        [ "$post_text" = "$command" ] && post_text=""
      fi

      # if previous line was not part of a string, then it each was a separate command
      if [ "${was_multi_line_string}" = false ];then
        # each line is a separate command, so replace newlines with semi-colons
        result="$(eval $(echo -e "${command//\\/\\\\}" | sed s'/\\n/;/g' | tr -d '`' | sed -e 's/$(//g' -e 's/)$//g') 2>/dev/null)"
        retval=$?
      else
        result="$(eval $(echo -e "${command//\\/\\\\}" | tr -d '`' | sed -e 's/$(//g' -e 's/)$//g') 2>/dev/null)"
        retval=$?
      fi
      [ "$was_multi_line_string" = false ] && line_is_bash=false
      [ "$multi_line_string" = false ] && line_is_bash=false
      # if the command was successful
      if [ $retval -eq 0 ];then
        # save its results to the markdown
        markdown="$markdown\n$pre_text$result$post_text"
        # save the literal input in $source
        source="${source}${command}"
        # the sub-shell must have ended, so next line is not bash (by default)
        line_is_bash=false
      fi
    fi

  elif [ "$line_is_bash" = false ];then

      command_line_count=0
      command=""
      markdown="$markdown\n$line"
      source="$source\n$line"
      multi_line_string=false
      #[ -z "${prev_line}" ] && [ -z "$line" ] && break

  fi

  ###### done working out what was in $line #######

#  xmessage "
#  was multi-line string: $was_multi_line_string
#  multi-line string:     $multi_line_string
#  line_was_bash:         $line_was_bash
#  line_is_bash:          $line_is_bash
#  command line count:    '${command_line_count}'
#  command:               '${command//\\/\\\\}'
#  result:                '${result}'
#  "

  was_multi_line_string=${multi_line_string}
  line_was_bash=${line_is_bash}
  prev_line="$line"
  [ ${retval:-1} -eq 0 ] && result=''
done < /tmp/markdown

# rebuild the markdown file
markdown_file="${1//.mdsh/}.md"

echo -e "${markdown}" > "$markdown_file"

echo "Saved as:"
echo
echo "Markdown file:  $markdown_file"
echo "Source file:    $1"
echo

unset prev_line
unset line_is_bash
unset multi_line_string
unset quote_count_is_even
unset file
unset text
unset command
unset command_line_count
unset result
unset retval
