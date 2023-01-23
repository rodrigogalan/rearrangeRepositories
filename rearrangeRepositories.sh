#!/bin/bash
clear

#Colours
greenColour="\e[0;32m\033[1m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
endColour="\033[0m\e[0m"

trap crtl_c INT

function crtl_c(){
	echo -e "\n\n${redColour}[!] Ending...${endColour}"
	tput cnorm
	exit 1
}

function helpPanel(){
	echo -n "
SYNOPSIS
	$0 [SHORT-OPTION]...
 	$0 LONG-OPTION

DESCRIPTION
	Rearrange all GitHub repositories that share X characters into one repository.

OPTIONS
	○  -h:

	   Display the help pannel.

	○  -f filename:
	
	   Select the JSON file with the github account username and token. The defaul value is \"./config.json\". The JSON structure must be:

	   {  
	  	   \"username\": \"jonh_doe\"
		   \"token\": \"github_pat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"
	   }


	○  -s string:
	
	   Select the common string between all the GitHub repositories.

"
	exit 0
}

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
			tput civis
		fi
		sleep 1
	done
	tput cnorm
	clear
}

# Function to get the github account credentials from config file
function getCredentials(){
	USERNAME=$(cat $CONFIGFILE 2> /dev/null | jq -r ".username" 2> /dev/null )
	TOKEN=$(cat $CONFIGFILE 2> /dev/null | jq -r ".token" 2> /dev/null )
	if [ -z $USERNAME ] && [ -z $TOKEN ]; then
		echo -e "${redColour}[X]${endColour} Something has gone wrong in reading the credentials."
		echo -e "\n${yellowColour}[*]${endColour} Check that the indicated file exists and has the correct structure."
		echo -e "\n${yellowColour}[*]${endColour} To view the help panel use the -h option.\n"
		exit 1
	fi	
}

# Function to obtain all the repositories beginning with the COMMON_STRING variable from the user account
function getRepositories(){
	MORE_RESULTS="?page=1&per_page=100"
	echo -e "${yellowColour}[*]${endColour}${turquoiseColour} GitHub API requests are being performed......${endColour}"
	while read repo; do
		REPOSITORIES_TO_REARRANGE=( "${REPOSITORIES_TO_REARRANGE[@]}" "$repo")
	done < <(curl -s \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer $TOKEN" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/users/${USERNAME}/repos${MORE_RESULTS} |
	jq -r ".[] | .name" 2> /dev/null|
	grep $COMMON_STRING)
	if [ ${#REPOSITORIES_TO_REARRANGE[@]} -eq 0 ]; then 
		echo "There has been a problem with the request to the GitHub api: "
		curl \
        	-H "Accept: application/vnd.github+json" \
        	-H "Authorization: Bearer $TOKEN" \
        	-H "X-GitHub-Api-Version: 2022-11-28" \
        	https://api.github.com/users/${USERNAME}/repos${MORE_RESULTS}
		exit 1
	fi

	echo -e "\nThe repositories to be rearranged are:\n"
	for repo in "${REPOSITORIES_TO_REARRANGE[@]}"; do
		echo -e "\t$repo";
	done
}

# Function to change name off all theese repos, deleting any possible space, changing "-" with "_" and lowering
function renameRepositories(){
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
						-H "Authorization: Bearer $TOKEN" \
						-H "X-GitHub-Api-Version: 2022-11-28" \
 						-d '{ "name":"'"${NEW_NAME}"'" }' \
 						https://api.github.com/repos/${USERNAME}/${repo} > /dev/null;
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
function checkSubarray(){
	local -n SUBARRAY=$1
	local -n ARRAY=$2
	ARRAY_COPY=("${ARRAY[@]}")

	# Check if the arrays contains only integer numbers
	for e in "${SUBARRAY[@]}"; do
		if ! [[ $e =~ ^[0-9]+$ ]]; then
			echo -e "${redColour}[!]${endColour} All characters must be integers separated by spaces."
   			return 1
		fi
	done

	# Check if that numbers correspond with the index in the array
	for index in "${SUBARRAY[@]}"; do
		if ! [ ${ARRAY[$index]} ]; then
			echo -e "${redColour}[!]${endColour} The possible numbers to enter are: ${!REPOSITORIES_RENAMED_COPY[@]}"
			return 1			
		fi
	done
	return 0
}

# Function to create a json with the desired repository structure
function createJson(){
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
		for (( week=1; week<=7; week++ )); do
			echo
			read -r -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Enter the numbers associated with the repositories corresponding with the week ${week}: ${endColour}")" -a repos

			# Commands to verify whether the variables entered are correct or not
			checkSubarray repos REPOSITORIES_RENAMED_COPY
			while (( $? )); do
				read -r -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Enter from the beginning again the numbers associated with week ${week}: ${endColour}")" -a repos
				checkSubarray repos REPOSITORIES_RENAMED_COPY
			done

			# Loop to remove already selected repositories
			for repo in "${repos[@]}"; do 
				unset -v 'REPOSITORIES_RENAMED_COPY[$repo]'
			done

			# Commands to add the selected repositories to the structure
			[[ -v REPOSITORY_STRUCTURE[semana_$week] ]] && REPOSITORY_STRUCTURE[semana_$week]+=" ${repos[@]}"
			[[ -v REPOSITORY_STRUCTURE[semana_$week] ]] || REPOSITORY_STRUCTURE[semana_$week]=${repos[@]}

			# Conditionals to check if the process has finished
			if [ ${#REPOSITORIES_RENAMED_COPY[@]} -gt 0 ]; then
				if [ $week != 7 ]; then
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
			for ((week=1; week<=7; week++)); do
				echo -e "\tsemana_$week →  "
				for e in ${REPOSITORY_STRUCTURE[semana_$week]}; do
					echo -e "\t\t${REPOSITORIES_RENAMED[${e}]}"
				done
				echo
			done
		fi
	done
}

# Function to create the new repository to store the other ones
function createRepository(){
	echo -e "${yellowColour}[*]${endColour}${turquoiseColour} A new repository will be created to store the remaining${endColour}"
	read -p "$(echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} Enter a name for the new repository: ${endColour}")" NEW_REPOSITORY_NAME
	NEW_REPOSITORY_NAME=$(echo ${NEW_REPOSITORY_NAME} | sed 's/ /_/g')
	read -p "$(echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} Enter the description for the new repository: ${endColour}")" NEW_REPOSITORY_DESCRIPTION
	curl -s \
  	-X POST \
  	-H "Accept: application/vnd.github+json" \
  	-H "Authorization: Bearer $TOKEN"\
  	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/user/repos \
  	-d '{"name":"'"${NEW_REPOSITORY_NAME}"'","description":"'"$NEW_REPOSITORY_DESCRIPTION"'","homepage":"https://github.com","private":false,"has_issues":true,"has_projects":true,"has_wiki":true}' > /dev/null
}

# Function to donwload the repositories
function donwloadRepositories(){
	cd ${0%/*}; cd ..
	git clone https://github.com/${USERNAME}/${NEW_REPOSITORY_NAME} &> /dev/null
	cd ${NEW_REPOSITORY_NAME}
	echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} All the repositories will be downloaded following the chosen folder structure in the path $(pwd)${endColour}"
	echo
	for ((week=1; week<=7; week++)); do
		mkdir semana_$week; cd semana_$week
		echo -e "${turquoiseColour}semana_${week}${endColour}"
		for e in ${REPOSITORY_STRUCTURE[semana_$week]}; do
			echo -e "\tdownloading ${REPOSITORIES_RENAMED[${e}]}..."
			git clone  https://github.com/${USERNAME}/${REPOSITORIES_RENAMED[${e}]} &> /dev/null
		done
		echo
		cd ..
	done
}

# Function to upload the repository
function uploadRepository(){
	echo -e "${yellowColour}[*]${endColour}${turquoiseColour} All git logs will be removed from the repositories...${endColour}"
	find -type d -path "./*/*/.git" -exec rm -rf {} +
	git add -A 
	git commit -m "Initial commit" > /dev/null
	echo -e "\n${yellowColour}[*]${endColour}${turquoiseColour} The total repository will be uploaded to the GitHub account...${endColour}"
	git push &> /dev/null
	clear
}

# Function to remove all the repositories from the GitHub account
function removeRepositories(){
	while true; do
		echo
		read -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Do you want to remove the rearranged repositories from your GitHub account? Is it recommended to check the new repository before accepting [Y/n]: ${endColour}")" ANSWER
		case $ANSWER in
			[Yy]*) for repo in "${REPOSITORIES_RENAMED[@]}"; do
				curl \
				-X DELETE \
				-H "Accept: application/vnd.github+json" \
				-H "Authorization: Bearer ${TOKEN}"\
				-H "X-GitHub-Api-Version: 2022-11-28" \
				https://api.github.com/repos/${USERNAME}/${repo}
			done
			break;;
			[Nn]*) break ;; 
			*) echo "Please answer yes or no" ;;
		esac
	done
	clear

}

# Main function
COMMON_STRING="lab"
CONFIGFILE="./config.json"
while getopts "hf:s:" arg; do
	case "${arg}" in
		h) helpPanel ;;
		f) CONFIGFILE=$OPTARG ;; 
		s) COMMON_STRING=$OPTARG ;;
	esac
done
dependencies
getCredentials
getRepositories
renameRepositories
echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Now is time to create the repository structure desired${endColour}"
createJson
while true; do       
	echo
	read -p "$(echo -e "${yellowColour}[*]${endColour}${turquoiseColour} Is the structure correct? [Y/n]: ${endColour}")" ANSWER
	case $ANSWER in
		[yY]*) clear; break ;;
		[nN]*) clear         
			echo -e "${yellowColour}[*]${endColour}${turquoiseColour} The structure is going to be repeated.${endColour}" 
			createJson ;;
		*) echo "Please answer yes or no" ;;
	esac
done
createRepository
donwloadRepositories
uploadRepository
removeRepositories
