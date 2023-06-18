#!/bin/bash
clear

#Colours
greenColour="\e[0;32m\033[1m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
endColour="\033[0m\e[0m"

trap crtl_c INT

function crtl_c(){
  err Ending...
  tput cnorm
  exit 1
}

function err(){
  echo -e "[$(date +"%m-%d-%Y %H:%M:%S")]: ${redColour}$*${endColour}" >&2
}

# Function to print the help
function help_panel(){
  cat <<EOF
SYNOPSIS
  $(basename $0) [OPTION]...

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
function dependencies(){
  tput civis
  clear
  dependencies=(curl jq)

  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Checking the required programs...${endColour}"
  
  for program in "${dependencies[@]}"; do
    echo -ne "\n${yellowColour}[*]${endColour} Tool${blueColour} $program${endColour}..."

    if [ -f /usr/bin/$program ]; then
      echo -e " ${greenColour}(V)${endColour}"
    else
      echo -e " ${redColour}(X)${endColour}\n"
      echo -e "${yellowColour}[*]${endColour} Instaling tool ${blueColour}$program${endColour}..."
      tput cnorm
      sudo apt-get install $program -y > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        err "The dependencie $program is necessary"
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
function get_credentials(){
  if [ -z $GITHUB_USERNAME ]; then
    err "Variable GITHUB_USERNAME does not exist"
    err "To view the help panel use the -h option."
    exit 1
  fi

  if [ -z $GITHUB_TOKEN ]; then
    err "Variable GITHUB_TOKEN does not exist"
    err "To view the help panel use the -h option."
    exit 1
  fi
}

# Function to obtain all the repositories beginning with the COMMON_STRING variable from the user account
function get_repositories(){
  MORE_RESULTS="?page=1&per_page=100"
  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} GitHub API requests are being performed......${endColour}"
  while read repo; do
    REPOSITORIES_TO_REARRANGE=( "${REPOSITORIES_TO_REARRANGE[@]}" "$repo")
  done < <(curl -s \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/users/${GITHUB_USERNAME}/repos${MORE_RESULTS} \
  | jq -r ".[] | .name" 2> /dev/null \
  | grep $COMMON_STRING)
  if [ ${#REPOSITORIES_TO_REARRANGE[@]} -eq 0 ]; then 
    err "GitHub api request failed: "
    curl \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/users/${GITHUB_USERNAME}/repos${MORE_RESULTS}
    exit 1
  fi

  echo -e "\nThe repositories to be rearranged are:\n"
  for repo in "${REPOSITORIES_TO_REARRANGE[@]}"; do
    echo -e "\t$repo";
  done
}

# Function to change name off all theese repos, deleting any possible space, changing "-" with "_" and lowering
function rename_repositories(){
  echo 
  echo 
  while true; do
    read -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Do you want the repository names to be normalized by making them lowercase and changing hyphens to underscores?${endColour} [Y/n]: ")" yn
      case $yn in
        [Yy]* )	for repo in "${REPOSITORIES_TO_REARRANGE[@]}"; do 
          NEW_NAME=$(echo $repo | tr '[:upper:]' '[:lower:]' | sed "s/-/_/g") ;
          if [ $repo != $NEW_NAME ]; then 
            curl -s \
              -X PATCH \
              -H "Accept: application/vnd.github+json" \
              -H "Authorization: Bearer $GITHUB_TOKEN" \
              -H "X-GitHub-Api-Version: 2022-11-28" \
              -d '{ "name":"'"${NEW_NAME}"'" }' \
              https://api.github.com/repos/${GITHUB_USERNAME}/${repo} > /dev/null;
          fi
          REPOSITORIES_RENAMED=("${REPOSITORIES_RENAMED[@]}" "$NEW_NAME")
        done

        break;;
      [Nn]* ) REPOSITORIES_RENAMED=("${REPOSITORIES_TO_REARRANGE[@]}"); break;;
        * ) echo "Please answer yes or no.";;
      esac
  done
  clear 
}

# Function to check if an array is a subarray of another array
function check_subarray(){
  local -n SUBARRAY=$1
  local -n ARRAY=$2

  # Check if the arrays contains only integer numbers
  for e in "${SUBARRAY[@]}"; do
    if ! [[ $e =~ ^[0-9]+$ ]]; then
      err "All characters must be integers separated by spaces."
      return 1
    fi
  done

  # Check if that numbers correspond with the index in the array
  for index in "${SUBARRAY[@]}"; do
    if ! [ ${ARRAY[$index]} ]; then
      echo "The possible numbers to enter are: ${!REPOSITORIES_RENAMED_COPY[@]}"
      return 1			
    fi
  done
  return 0
}

# Function to create a json with the desired repository structure
function create_json(){
  unset REPOSITORY_STRUCTURE
  declare -gA REPOSITORY_STRUCTURE
  echo
  echo "The numbered list of repositories is:"
  echo
  for repo in "${!REPOSITORIES_RENAMED[@]}"; do
    echo -e "\t$repo ${REPOSITORIES_RENAMED[$repo]}"
  done
  REPOSITORIES_RENAMED_COPY=("${REPOSITORIES_RENAMED[@]}")
  while [ ${#REPOSITORIES_RENAMED_COPY[@]} -gt 0 ]; do
    for (( folder=1; folder<=${NUMBER_OF_FOLDERS}; folder++ )); do
      echo
      read -r -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Enter the numbers associated with the repositories corresponding with the folder ${folder}: ${endColour}")" -a repos

      # Commands to verify whether the variables entered are correct or not
      check_subarray repos REPOSITORIES_RENAMED_COPY
      while (( $? )); do
        read -r -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Enter from the beginning again the numbers associated with folder ${folder}: ${endColour}")" -a repos
        check_subarray repos REPOSITORIES_RENAMED_COPY
      done

      # Loop to remove already selected repositories
      for repo in "${repos[@]}"; do 
        unset -v 'REPOSITORIES_RENAMED_COPY[$repo]'
      done

      # Commands to add the selected repositories to the structure
      [[ -v REPOSITORY_STRUCTURE[${FOLDER_NAMES}_$folder] ]] && REPOSITORY_STRUCTURE[${FOLDER_NAMES}_$folder]+=" ${repos[@]}"
      [[ -v REPOSITORY_STRUCTURE[${FOLDER_NAMES}_$folder] ]] || REPOSITORY_STRUCTURE[${FOLDER_NAMES}_$folder]=${repos[@]}

      # Conditionals to check if the process has finished
      if [ ${#REPOSITORIES_RENAMED_COPY[@]} -gt 0 ]; then
        if [ $folder != ${NUMBER_OF_FOLDERS} ]; then
          echo "The remaining repositories are: "
          for index in ${!REPOSITORIES_RENAMED_COPY[@]}; do 
            echo -n "$index  "
          done
        fi
      else
        echo "There are no remaining repositories"
        break
      fi
    done

    # Loop to loop back through the array if there are missing repositories or to terminate if there are not.
    if [ ${#REPOSITORIES_RENAMED_COPY[@]} -gt 0 ]; then
      echo 
      echo "The remaining repositories to be added to the structure are: "
      for index in ${!REPOSITORIES_RENAMED_COPY[@]}; do 
        echo -n "$index  "
      done
    else
      clear
      echo -e "${yellowColour}[*]${endColour}${turquoiseColour} The structure is:${endColour}"
      for ((folder=1; folder<=${NUMBER_OF_FOLDERS}; folder++)); do
        echo -e "\t${FOLDER_NAMES}_$folder →  "
        for e in ${REPOSITORY_STRUCTURE[${FOLDER_NAMES}_$folder]}; do
          echo -e "\t\t${REPOSITORIES_RENAMED[${e}]}"
        done
        echo
      done
    fi
  done
}

# Function to create the new repository to store the other ones
function create_repository(){
  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} A new repository will be created to store the remaining${endColour}"
  read -p "$(echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} Enter a name for the new repository: ${endColour}")" NEW_REPOSITORY_NAME
  NEW_REPOSITORY_NAME=$(echo ${NEW_REPOSITORY_NAME} | sed 's/ /_/g')
  read -p "$(echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} Enter the description for the new repository: ${endColour}")" NEW_REPOSITORY_DESCRIPTION

  curl -s \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN"\
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/user/repos \
    -d '{"name":"'"${NEW_REPOSITORY_NAME}"'","description":"'"$NEW_REPOSITORY_DESCRIPTION"'","homepage":"https://github.com","private":false,"has_issues":true,"has_projects":true,"has_wiki":true}' > /dev/null

  if [ $? -ne 0 ]; then 
    err "GitHub api request failed: "
    curl -s \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GITHUB_TOKEN"\
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/user/repos \
      -d '{"name":"'"${NEW_REPOSITORY_NAME}"'","description":"'"$NEW_REPOSITORY_DESCRIPTION"'","homepage":"https://github.com","private":false,"has_issues":true,"has_projects":true,"has_wiki":true}' > /dev/null
    exit 1
  fi
}

# Function to donwload the repositories
function donwload_repositories(){
  cd ${0%/*}; cd ..
  git clone --quiet https://github.com/${GITHUB_USERNAME}/${NEW_REPOSITORY_NAME}
  cd ${NEW_REPOSITORY_NAME}
  echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} All the repositories will be downloaded following the chosen folder structure in the path $(pwd)${endColour}"
  echo
  for ((folder=1; folder<=${NUMBER_OF_FOLDERS}; folder++)); do
    mkdir ${FOLDER_NAMES}_$folder; cd ${FOLDER_NAMES}_$folder
    echo -e "${turquoiseColour}${FOLDER_NAMES}_${folder}${endColour}"
    unset GIT_REPOSITORY
    for e in ${REPOSITORY_STRUCTURE[${FOLDER_NAMES}_$folder]}; do 
      GIT_REPOSITORY+=(https://github.com/${GITHUB_USERNAME}/${REPOSITORIES_RENAMED[${e}]})
    done
    printf '\t%s\n' "${GIT_REPOSITORY[@]}"
    wait
    printf '%s\n' "${GIT_REPOSITORY[@]}" \
    | xargs -I{} -P10 bash -c 'git clone --quiet --depth 1 --single-branch {}'
    wait
    echo
    cd ..
  done
  clear
}

# Function to upload the repository
function upload_repository(){
  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} All git logs will be removed from the repositories...${endColour}"
  echo "The repository is in the path $(pwd)"
  find -type d -path "./*/*/.git" -exec rm -rf {} +
  git add -A 
  git commit --quiet -m "Initial commit"
  echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} The total repository will pushed to the GitHub account...${endColour}"
  git push
}

# Function to remove all the repositories from the GitHub account
function remove_repositories(){
  while true; do
    echo
    read -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Do you want to remove the rearranged repositories from your GitHub account? Is it recommended to check the new repository before accepting [Y/n]: ${endColour}")" ANSWER
    case $ANSWER in
      [Yy]*) for repo in "${REPOSITORIES_RENAMED[@]}"; do
        echo "Removing $repo"
        curl \
          -X DELETE \
          -H "Accept: application/vnd.github+json" \
          -H "Authorization: Bearer ${GITHUB_TOKEN}"\
          -H "X-GitHub-Api-Version: 2022-11-28" \
          https://api.github.com/repos/${GITHUB_USERNAME}/${repo}
      done
      break;;
      [Nn]*) break ;; 
      *) echo "Please answer yes or no" ;;
    esac
  done
  clear

}

# Main function
function main(){
  COMMON_STRING="lab"
  NUMBER_OF_FOLDERS=7
  FOLDER_NAMES="week"
  while getopts "hs:n:c:" arg; do
    case "${arg}" in
      s) COMMON_STRING=$OPTARG ;;
      n) NUMBER_OF_FOLDERS=$OPTARG ;;
      c) FOLDER_NAMES=$OPTARG ;;
      h | *) help_panel ;;
    esac
  done
  readonly COMMON_STRING
  readonly NUMBER_OF_FOLDERS
  readonly FOLDER_NAMES
  dependencies
  get_credentials
  get_repositories
  rename_repositories
  echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Now is time to create the repository structure desired${endColour}"
  create_json
  while true; do       
    echo
    read -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Is the structure correct? [Y/n]: ${endColour}")" ANSWER
    case $ANSWER in
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
}

main "$@"