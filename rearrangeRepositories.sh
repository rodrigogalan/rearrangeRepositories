#!/bin/bash
#
# Combine all GitHub repositories with a common name in one

clear

#Colours
greenColour="\e[0;32m\033[1m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
endColour="\033[0m\e[0m"

trap crtl_c INT

crtl_c(){
  err Ending...
  tput cnorm
  exit 1
}

err(){
  echo -e "[$(date +"%m-%d-%Y %H:%M:%S")]: ${redColour}$*${endColour}" >&2
}

# Function to print the help
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

# Function to check for necessary dependencies
dependencies(){
  tput civis
  clear
  local dependencies=(curl jq)

  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Checking the required programs...${endColour}"
  
  for dependency in "${dependencies[@]}"; do
    echo -ne "\n${yellowColour}[*]${endColour} Tool${blueColour} $dependency${endColour}..."

    if [ -f "/usr/bin/$dependency" ]; then
      echo -e " ${greenColour}(V)${endColour}"
    else
      echo -e " ${redColour}(X)${endColour}\n"
      echo -e "${yellowColour}[*]${endColour} Instaling tool ${blueColour}$dependency${endColour}..."
      tput cnorm
      sudo apt-get install "$dependency" -y > /dev/null 2>&1
      if [[ $? != 0 ]]; then
        err "The dependencie $dependency is necessary"
        exit 1
      fi
      tput civis
    fi
    sleep 1
  done
  tput cnorm
  clear
}

# Function to get the github account credentials from config file
get_credentials(){
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

# Function to obtain all the repositories beginning with the common_string variable from the user account
get_repositories(){
  local more_results="?page=1&per_page=100"

  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} GitHub API requests are being performed......${endColour}"

  http_get_repository=$(mktemp)

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
    cat "$http_get_repository"
    exit 1
  fi

  mapfile -t repositories_to_rearrange < <(jq -r ".[] | .name" <"$http_get_repository" 2> /dev/null \
    | grep "$common_string")

  if [ ${#repositories_to_rearrange[@]} -lt 1 ]; then 
    err "There are no repositories in the account \"${GITHUB_USERNAME}\" with the string \"$common_string\""
    exit 1
  fi

  echo -e "\nThe repositories to be rearranged are:\n"
  printf '%s\n' "${repositories_to_rearrange[@]}"
}

# Function to change name off all theese repos, deleting any possible space, changing "-" with "_" and lowering
rename_repositories(){
  echo 
  echo 
  while true; do
    read -rp "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Do you want the repository names to be normalized by making them lowercase and changing hyphens to underscores?${endColour} [Y/n]: ")" answer
      case $answer in
        [Yy]* )
          for repository_to_rearrange in "${repositories_to_rearrange[@]}"; do 
            local new_name
            new_name=${repository_to_rearrange,,}; repository_to_rearrange=${repository_to_rearrange//-/_}
            if [ "$repository_to_rearrange" != "$new_name" ]; then
              http_change_repository_name=$(mktemp)

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
                cat "$http_change_repository_name"
                exit 1
              fi
            fi
          done
          repositories_to_rearrange=( "${repositories_to_rearrange[@],,}" ); repositories_to_rearrange=( "${repositories_to_rearrange[@]//-/_}" )
          break;;

        [Nn]* ) break;;

        * ) echo "Please answer yes or no.";;
      esac
  done
  clear 
}

# Function to check if an array is a subarray of another array
check_subarray(){
  local -n subarrays=$1
  local -n array_total=$2

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
      err "The possible numbers to enter are: ${!repositories_to_rearrange_copy[*]}"
      return 1			
    fi
  done
  return 0
}

# Function to create a json with the desired repository structure
create_json(){
  unset repository_structure
  declare -gA repository_structure

  echo -e "\nThe numbered list of repositories is:\n"
  for repository_to_rearrange in "${!repositories_to_rearrange[@]}"; do
    printf "\t%s  %s\n" "$repository_to_rearrange" "${repositories_to_rearrange[$repository_to_rearrange]}"
  done

  repositories_to_rearrange_copy=("${repositories_to_rearrange[@]}")
  while [ ${#repositories_to_rearrange_copy[@]} -gt 0 ]; do
    for (( folder=1; folder<=number_of_folders; folder++ )); do
      echo
      read -r -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Enter the numbers associated with the repositories corresponding with the folder ${folder}: ${endColour}")" -a repositories_index

      # Commands to verify whether the variables entered are correct or not
      while ! check_subarray repositories_index repositories_to_rearrange_copy; do
        read -r -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Enter from the beginning again the numbers associated with folder ${folder}: ${endColour}")" -a repositories_index
      done

      # Loop to remove already selected repositories
      for repository_index in "${repositories_index[@]}"; do 
        unset -v 'repositories_to_rearrange_copy[${repository_index}]'
      done

      # Commands to add the selected repositories to the structure
      [[ -v repository_structure[${folder_names}_$folder] ]] && repository_structure[${folder_names}_$folder]+=" ${repositories_index[*]}"
      [[ -v repository_structure[${folder_names}_$folder] ]] || repository_structure[${folder_names}_$folder]=${repositories_index[*]}

      # Conditionals to check if the process has finished
      if [ ${#repositories_to_rearrange_copy[@]} -gt 0 ]; then
        if [ "$folder" != "${number_of_folders}" ]; then
          echo "The remaining repositories are: "
          printf '%s  ' "${!repositories_to_rearrange_copy[@]}"
        fi
      else
        echo "There are no remaining repositories"
        break
      fi
    done

    # Loop to loop back through the array if there are missing repositories or to terminate if there are not.
    if [ ${#repositories_to_rearrange_copy[@]} -gt 0 ]; then
      echo 
      echo "The remaining repositories to be added to the structure are: "
      for repository_to_rearrange_copy in "${!repositories_to_rearrange_copy[@]}"; do 
        echo -n "$repository_to_rearrange_copy  "
      done
    else
      clear
      echo -e "${yellowColour}[*]${endColour}${turquoiseColour} The structure is:${endColour}"
      for ((folder=1; folder<=number_of_folders; folder++)); do
        echo -e "\t${folder_names}_$folder →  "
        for e in ${repository_structure[${folder_names}_$folder]}; do
          echo -e "\t\t${repositories_to_rearrange[${e}]}"
        done
        echo
      done
    fi
  done
}

# Function to create the new repository to store the other ones
create_repository(){
  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} A new repository will be created to store the remaining${endColour}"
  read -rp "$(echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} Enter a name for the new repository: ${endColour}")" new_repository_name
  new_repository_name="${new_repository_name///_}"
  read -rp "$(echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} Enter the description for the new repository: ${endColour}")" new_repository_description
  
  http_create_repositoy=$(mktemp)

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
    cat "$http_create_repositoy"
    exit 1
  fi
}


# Function to donwload the repositories
donwload_repositories(){
  cd "${0%/*}"; cd ..
  git clone --quiet "https://github.com/${GITHUB_USERNAME}/${new_repository_name}" || { err "There is already a repository called ${new_repository_name} in $(pwd)"; exit 1 ; }
  cd "${new_repository_name}" || { err "The repository ${new_repository_name} did not download correctly"; exit 1; }
  echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} All the repositories will be downloaded following the chosen folder structure in the path $(pwd)${endColour}"
  echo
    for ((folder=1; folder<=number_of_folders; folder++)); do
      (
      mkdir "${folder_names}"_"$folder"; cd "${folder_names}"_"$folder" || { err "failed to create change directory to ${folder_names}_$folder"; exit 1; }
      echo -e "${turquoiseColour}${folder_names}_${folder}${endColour}"
      unset git_repository
      for e in ${repository_structure[${folder_names}_$folder]}; do 
        git_repository+=("https://github.com/${GITHUB_USERNAME}/${repositories_to_rearrange[${e}]}")
      done
      printf '\t%s\n' "${git_repository[@]}"
      wait
      printf '%s\n' "${git_repository[@]}" \
      | xargs -I{} -P10 bash -c 'git clone --quiet --depth 1 --single-branch {}'
      wait
      echo
      )
    done
  clear
}

# Function to upload the repository
upload_repository(){
  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} All git logs will be removed from the repositories...${endColour}"
  echo "The repository is in the path $(pwd)"
  find . -type d -path "./*/*/.git" -exec rm -rf {} +
  git add -A 
  git commit --quiet -m "Initial commit" || err ""
  echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} The total repository will pushed to the GitHub account...${endColour}"
  git push
}

# Function to remove all the repositories from the GitHub account
remove_repositories(){
  while true; do
    echo
    read -rp "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Do you want to remove the rearranged repositories from your GitHub account? Is it recommended to check the new repository before accepting [Y/n]: ${endColour}")" answer
    case $answer in
      [Yy]*) 
        for repository_to_rearrange in "${repositories_to_rearrange[@]}"; do
          echo "Removing $repository_to_rearrange"
          http_delete_repositoy=$(mktemp)

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
            cat "$http_delete_repositoy"
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
  common_string="lab"
  number_of_folders=7
  folder_names="week"
  while getopts ":hs:n:c:" arg; do
    case "${arg}" in
      h) help_panel ;;
      s) common_string=$OPTARG ;;
      n) number_of_folders=$OPTARG ;;
      c) folder_names=$OPTARG ;;
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
  shift "$((${OPTIND}-1))"
  readonly common_string
  readonly number_of_folders
  readonly folder_names
  dependencies
  get_credentials
  get_repositories
  rename_repositories
  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Now is time to create the repository structure desired${endColour}"
  create_json
  while true; do       
    echo
    read -rp "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Is the structure correct? [Y/n]: ${endColour}")" answer
    case $answer in
      [yY]*) clear; break ;;
      [nN]*) clear         
        echo -e "${yellowColour}[*]${endColour}${turquoiseColour} The structure is going to be repeated.${endColour}" 
        create_json ;;
      *) echo "Please answer yes or no" ;;
    esac
  done
  create_repository
  donwload_repositories
  upload_repository
  remove_repositories
  trap '{ rm -f -- "$http_get_repository"; }' EXIT
  trap '{ rm -f -- "$http_change_repository_name"; }' EXIT 
  trap '{ rm -f -- "$http_create_repositoy"; }' EXIT
  trap '{ rm -f -- "$http_delete_repositoy"; }' EXIT
}

main "$@"