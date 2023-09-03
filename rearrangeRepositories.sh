#!/bin/bash
#
# Combine all GitHub repositories with a common name in one

# Avoid unset variables 
# set -u

# Trap commmands
trap crtl_c INT

# Colour global variables
readonly GREENCOLOUR="\e[0;32m\033[1m"
readonly REDCOLOUR="\e[0;31m\033[1m"
readonly BLUECOLOUR="\e[0;34m\033[1m"
readonly YELLOWCOLOUR="\e[0;33m\033[1m"
readonly TURQUOISECOLOUR="\e[0;36m\033[1m"
readonly ENDCOLOUR="\033[0m\e[0m"

#######################################
# End execution
# Arguments:
#   None
# Return:
#   Return 1
#######################################
crtl_c(){
  echo
  err Ending...
  tput cnorm
  exit 1
}

#######################################
# Creates an error message
# Arguments:
#   None
# Outputs:
#   Error message in stderr
#######################################
err(){
  echo -e "[$(date +"%m-%d-%Y %H:%M:%S")]: ${REDCOLOUR}$*${ENDCOLOUR}" >&2
}

#######################################
# Show the help panel
# Arguments:
#   None
# Outputs:
#   Show help panel
# Return:
#   Return 0
#######################################
help_panel(){
  cat <<EOF
SYNOPSIS
  $(basename "$0") [OPTION]...

DESCRIPTION
  Rearrange all GitHub repositories that share X characters into one repository.
  GITHUB_USERNAME/GITHUB_TOKEN must be set via environment variables

OPTIONS
  ○  -h:
    Display the help pannel.

  ○  -s string:
    Select the common string between all the GitHub repositories.

  ○  -n number_of_folders:
    Enter the number of folders desired to rearrange the repositories. The default number is 7.

  ○  -c folder_names:
    Customize folder names. The default name is "week".

EOF
  exit 0
}

#######################################
# Check necessary dependencies
# Arguments:
#   None
# Returns:
#   0 if dependency is installed, non-zero on error.
#######################################
dependencies(){
  tput civis
  clear
  local dependencies
  dependencies=(curl jq)

  echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Checking the required programs...${ENDCOLOUR}"
  
  for dependency in "${dependencies[@]}"; do
    echo -ne "\n${YELLOWCOLOUR}[*]${ENDCOLOUR} Tool${BLUECOLOUR} $dependency${ENDCOLOUR}..."

    if [ -f "/usr/bin/$dependency" ]; then
      echo -e " ${GREENCOLOUR}(V)${ENDCOLOUR}"
    else
      echo -e " ${REDCOLOUR}(X)${ENDCOLOUR}\n"
      echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR} Instaling tool ${BLUECOLOUR}$dependency${ENDCOLOUR}..."
      tput cnorm
      # sudo apt-get install "$dependency" -y > /dev/null 2>&1

      if ! sudo apt-get install "$dependency" -y > /dev/null 2>&1; then
        err "The dependencie $dependency is necessary"
        exit 1
      else echo -e "\tInstalled ${GREENCOLOUR}(V)${ENDCOLOUR}\r"
      fi
      tput civis
    fi
    sleep 1
  done
  tput cnorm
  clear
}

#######################################
# Check if github account credentials are defined
# Globals:
#   GITHUB_USERNAME
#   GITHUB_TOKEN
# Arguments:
#   None
# Returns:
#   0 if credentials exist, non-zero if not.
#######################################
check_credentials(){
  if [ -z "$GITHUB_USERNAME" ]; then
    err "Variable GITHUB_USERNAME does not exist"
    err "To view the help panel use the -h option."
    exit 1
  fi

  if [ -z "$GITHUB_TOKEN" ]; then
    err "Variable GITHUB_TOKEN does not exist"
    err "To view the help panel use the -h option."
    exit 1
  fi
}

#######################################
# Get all the repositories beginning with the common_string variable from the user account
# Globals:
#   GITHUB_USERNAME
#   GITHUB_TOKEN
# Arguments:
#   repositories: array with the repositories
# Outputs:
#   List with the repositories
#######################################
get_repositories(){
  local -n repositories=$1
  local more_results
  more_results="?page=1&per_page=100"

  echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} GitHub API requests are being performed......${ENDCOLOUR}"

  local http_get_repository
  http_get_repository=$(mktemp)
  trap '{ rm -f -- "$http_get_repository"; }' EXIT

  local http_code
  http_code=$(curl -sL \
  --output "$http_get_repository" \
  --write-out "%{http_code}" \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/users/${GITHUB_USERNAME}/repos${more_results}")

  if [ "$http_code" -ge 400 ]; then
    err "GitHub api request failed: "
    cat "$http_get_repository" >&2 
    exit 1
  fi

  mapfile -t repositories < <(jq -r ".[] | .name" <"$http_get_repository" 2> /dev/null \
    | grep "$COMMON_STRING")

  if [ ${#repositories[@]} -lt 1 ]; then 
    err "There are no repositories in the account \"${GITHUB_USERNAME}\" with the string \"$COMMON_STRING\""
    exit 1
  fi

  echo -e "\nThe repositories to be rearranged are:\n"
  printf '%s\n' "${repositories[@]}"
}

#######################################
# Rename repos, deleting any possible space, changing "-" with "_" and lowering
# Globals:
#   GITHUB_USERNAME
#   GITHUB_TOKEN
# Arguments:
#   None
# Outputs:
#   List with the repositories renamed
#######################################
rename_repositories(){
  echo 
  echo
  local -n repositories
  repositories=$1
  local new_name
  local answer
  while true; do
    read -rp "$(echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Do you want the repository names to be normalized by making them lowercase and changing hyphens to underscores?${ENDCOLOUR} [Y/n]: ")" answer
      case $answer in
        [Yy]* )
          for repository_to_rearrange in "${repositories[@]}"; do 
            new_name=${repository_to_rearrange,,}; repository_to_rearrange=${repository_to_rearrange//-/_}
            if [ "$repository_to_rearrange" != "$new_name" ]; then

              local http_change_repository_name
              http_change_repository_name=$(mktemp)
              trap '{ rm -f -- "$http_change_repository_name"; }' EXIT 

              local http_code
              http_code=$(curl -sL \
                --output "$http_change_repository_name" \
                --write-out "%{http_code}" \
                -X PATCH \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer $GITHUB_TOKEN" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                -d '{ "name":"'"${new_name}"'" }' \
                "https://api.github.com/repos/${GITHUB_USERNAME}/${repository_to_rearrange}")

              if [ "$http_code" -ge 400 ]; then
                err "The repository $repository_to_rearrange could not be renamed: "
                cat "$http_change_repository_name" >&2
                exit 1
              fi
            fi
          done
          repositories=( "${repositories[@],,}" ); repositories=( "${repositories[@]//-/_}" )
          break;;

        [Nn]* ) break;;

        * ) echo "Please answer yes or no.";;
      esac
  done
  clear 
}

#######################################
# Check if an array is a subarray of another array
# Arguments:
#   Subarray
#   Array
# Returns:
#   0 if subarray is part of array, non-zero if not.
#######################################
check_subarray(){
  local -n subarrays
  local -n array_total
  subarrays=$1
  array_total=$2

  # Check if the arrays contains only integer numbers
  for subarray in "${subarrays[@]}"; do
    if ! [[ ${subarray} =~ ^[0-9]+$ ]]; then
      err "All characters must be integers separated by spaces."
      return 1
    fi
  done

  # Check if that numbers correspond with the index in the array
  for subarray in "${subarrays[@]}"; do
    if ! [ "${array_total[$subarray]}" ]; then
      err "The possible numbers to enter are: ${!array_total[*]}"
      return 1			
    fi
  done
  return 0
}

#######################################
# Create a json with the desired repository structure
# Arguments:
#   None
# Outputs:
#   Associative array with the repository structure
#######################################
create_json(){
  local -n repository_structure
  repository_structure=$1
  local -n repositories
  repositories=$2
  local repositories_copy
  repositories_copy=("${repositories[@]}")


  echo -e "\nThe numbered list of repositories is:\n"
  for repository_to_rearrange in "${!repositories[@]}"; do
    printf "\t%s  %s\n" "$repository_to_rearrange" "${repositories[$repository_to_rearrange]}"
  done

  while [ ${#repositories_copy[@]} -gt 0 ]; do
    for (( folder=1; folder<=NUMBER_OF_FOLDERS; folder++ )); do
      echo
      read -r -p "$(echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Enter the numbers associated with the repositories corresponding with the folder ${folder}: ${ENDCOLOUR}")" -a repositories_index

      # Commands to verify whether the variables entered are correct or not
      while ! check_subarray repositories_index repositories_copy; do
        read -r -p "$(echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Enter from the beginning again the numbers associated with folder ${folder}: ${ENDCOLOUR}")" -a repositories_index
      done

      # Loop to remove already selected repositories
      for repository_index in "${repositories_index[@]}"; do 
        unset -v 'repositories_copy[${repository_index}]'
      done

      # Commands to add the selected repositories to the structure
      [[ -v repository_structure[${FOLDER_NAMES}_$folder] ]] && repository_structure[${FOLDER_NAMES}_$folder]+=" ${repositories_index[*]}"
      [[ -v repository_structure[${FOLDER_NAMES}_$folder] ]] || repository_structure[${FOLDER_NAMES}_$folder]=${repositories_index[*]}

      # Conditionals to check if the process has finished
      if [ ${#repositories_copy[@]} -gt 0 ]; then
        if [ "$folder" != "${NUMBER_OF_FOLDERS}" ]; then
          echo "The remaining repositories are: "
          printf '%s  ' "${!repositories_copy[@]}"
        fi
      else
        echo "There are no remaining repositories"
        break
      fi
    done

    # Loop to loop back through the array if there are missing repositories or to terminate if there are not.
    if [ ${#repositories_copy[@]} -gt 0 ]; then
      echo 
      echo "The remaining repositories to be added to the structure are: "
      for repository_to_rearrange_copy in "${!repositories_copy[@]}"; do 
        echo -n "$repository_to_rearrange_copy  "
      done
    else
      clear
      echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} The structure is:${ENDCOLOUR}"
      for ((folder=1; folder<=NUMBER_OF_FOLDERS; folder++)); do
        echo -e "\t${FOLDER_NAMES}_$folder →  "
        for e in ${repository_structure[${FOLDER_NAMES}_$folder]}; do
          echo -e "\t\t${repositories[${e}]}"
        done
        echo
      done
    fi
  done
}

#######################################
# Create the new repository to store the other ones
# Globals:
#   GITHUB_USERNAME
#   GITHUB_TOKEN
# Arguments:
#   None
#######################################
create_repository(){
  local -n new_repository_name
  new_repository_name=$1

  echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} A new repository will be created to store the remaining${ENDCOLOUR}"
  read -rp "$(echo -e "\n${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Enter a name for the new repository: ${ENDCOLOUR}")" new_repository_name
  new_repository_name="${new_repository_name// /_}"
  read -rp "$(echo -e "\n${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Enter the description for the new repository: ${ENDCOLOUR}")" new_repository_description
  
  local http_create_repositoy
  http_create_repositoy=$(mktemp)
  trap '{ rm -f -- "$http_create_repositoy"; }' EXIT

  local http_code
  http_code=$(curl -sL \
    --output "$http_create_repositoy" \
    --write-out "%{http_code}" \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d '{"name":"'"${new_repository_name}"'","description":"'"$new_repository_description"'","homepage":"https://github.com","private":false,"has_issues":true,"has_projects":true,"has_wiki":true}' \
    "https://api.github.com/user/repos")
  
  if [ "$http_code" -ge 400 ]; then
    err "The repository $new_repository_name could not be created"
    cat "$http_create_repositoy" >&2 
    exit 1
  fi
}


#######################################
# Donwload the repositories
# Globals:
#   GITHUB_USERNAME
#   GITHUB_TOKEN
# Arguments:
#   None
#######################################
donwload_repositories(){
  local -n new_repository_name
  new_repository_name=$1
  local -n repositories
  repositories=$2

  cd "${0%/*}" || { err "The cd did not success "; exit 1; }
  cd .. || { err "The cd did not success "; exit 1; }
  git clone --quiet "https://github.com/${GITHUB_USERNAME}/${new_repository_name}" 2>&1 | { grep -v "warning" || true; }|| { err "There is already a repository called ${new_repository_name} in $(pwd)"; exit 1 ; }
  cd "${new_repository_name}" || { err "The repository ${new_repository_name} did not download correctly"; exit 1; }
  echo -e "\n${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} All the repositories will be downloaded following the chosen folder structure in the path $(pwd)${ENDCOLOUR}"
  echo
    for ((folder=1; folder<=NUMBER_OF_FOLDERS; folder++)); do
      (
      mkdir "${FOLDER_NAMES}"_"$folder"; cd "${FOLDER_NAMES}"_"$folder" || { err "failed to create change directory to ${FOLDER_NAMES}_$folder"; exit 1; }
      echo -e "${TURQUOISECOLOUR}${FOLDER_NAMES}_${folder}${ENDCOLOUR}"
      unset git_repository
      for e in ${REPOSITORY_STRUCTURE[${FOLDER_NAMES}_$folder]}; do 
        git_repository+=("https://github.com/${GITHUB_USERNAME}/${repositories[${e}]}")
      done
      printf '\t%s\n' "${git_repository[@]}"
      wait
      printf '%s\n' "${git_repository[@]}" \
      | xargs -I{} -P10 bash -c 'git clone --quiet --depth 1 --single-branch {} 2>&1 | grep -v "warning"'
      wait
      echo
      )
    done
  clear
}

#######################################
# Upload the repository
# Globals:
#   GITHUB_USERNAME
#   GITHUB_TOKEN
# Arguments:
#   None
#######################################
upload_repository(){
  echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} All git logs will be removed from the repositories...${ENDCOLOUR}"
  echo "The repository is in the path $(pwd)"
  find . -type d -path "./*/*/.git" -exec rm -rf {} +
  git add -A 
  git commit --quiet -m "Initial commit" || { err "The git commit did not success "; return 1; }
  echo -e "\n${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} The total repository will pushed to the GitHub account...${ENDCOLOUR}"
  git push
}

#######################################
# Remove all the repositories from the GitHub account
# Globals:
#   GITHUB_USERNAME
#   GITHUB_TOKEN
# Arguments:
#   None
#######################################
remove_repositories(){
  local -n repositories
  repositories=$1

  while true; do
    echo
    read -rp "$(echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Do you want to remove the rearranged repositories from your GitHub account? Is it recommended to check the new repository before accepting [Y/n]: ${ENDCOLOUR}")" answer
    case $answer in
      [Yy]*) 
        for repository_to_rearrange in "${repositories[@]}"; do
          echo "Removing $repository_to_rearrange"

          local http_delete_repositoy
          http_delete_repositoy=$(mktemp)
          trap '{ rm -f -- "$http_delete_repositoy"; }' EXIT

          local http_code
          http_code=$(curl -sL \
            --output "$http_delete_repositoy" \
            --write-out "%{http_code}" \
            -X DELETE \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}"\
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/${GITHUB_USERNAME}/${repository_to_rearrange}")

          if [ "$http_code" -ge 400 ]; then
            err "The repository $repository_to_rearrange could not be removed"
            cat "$http_delete_repositoy" >&2
            exit 1
          fi
        done
        break;;

      [Nn]*) break ;;

      *) echo "Please answer yes or no" ;;
    esac
  done
  clear
}

# Main function
main(){

  clear

  COMMON_STRING="lab"
  NUMBER_OF_FOLDERS=7
  FOLDER_NAMES="week"
  while getopts ":hs:n:c:" arg; do
    case "${arg}" in
      h) help_panel ;;
      s) COMMON_STRING=$OPTARG ;;
      n) NUMBER_OF_FOLDERS=$OPTARG ;;
      c) FOLDER_NAMES=$OPTARG ;;
      :) 
        err "${OPTARG} requires an argument"
        help_panel
        ;;
      *) 
        err "${OPTARG} invalid option"
        help_panel
        ;;
    esac
  done
  shift "$((OPTIND-1))"
  readonly COMMON_STRING
  readonly NUMBER_OF_FOLDERS
  readonly FOLDER_NAMES
  declare -A REPOSITORY_STRUCTURE

  dependencies
  check_credentials
  get_repositories REPOSITORIES_TO_REARRANGE
  rename_repositories REPOSITORIES_TO_REARRANGE
  readonly REPOSITORIES_TO_REARRANGE
  echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Now is time to create the repository structure desired${ENDCOLOUR}"
  create_json REPOSITORY_STRUCTURE REPOSITORIES_TO_REARRANGE
  while true; do       
    echo
    read -rp "$(echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} Is the structure correct? [Y/n]: ${ENDCOLOUR}")" answer
    case $answer in
      [yY]*) clear; break ;;
      [nN]*) clear         
        echo -e "${YELLOWCOLOUR}[*]${ENDCOLOUR}${TURQUOISECOLOUR} The structure is going to be repeated.${ENDCOLOUR}" 
        unset REPOSITORY_STRUCTURE
        create_json REPOSITORY_STRUCTURE REPOSITORIES_TO_REARRANGE ;;
      *) echo "Please answer yes or no" ;;
    esac
  done
  readonly REPOSITORY_STRUCTURE
  create_repository NEW_REPOSITORY_NAME
  readonly NEW_REPOSITORY_NAME
  donwload_repositories NEW_REPOSITORY_NAME REPOSITORIES_TO_REARRANGE
  upload_repository
  remove_repositories REPOSITORIES_TO_REARRANGE
}

main "$@"