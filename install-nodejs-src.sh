# -----------------------------------------------------------------------
# Author: 	    	Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/scripts
# Scipt Name:	  	install-nodejs-src.sh
# Script Ver:	  	0.1.1
# Description:		Script to install NodeJS from source.
#	
# Usage:	      	./install-nodejs-src.sh
# -----------------------------------------------------------------------

install_nodejs()
{

	# Source git: https://github.com/joyent/node
	# Binaries: https://nodejs.org/download/

	echo -e "\n==> Installing nodejs from automated script..."
	sleep 2s
	
	###############################
	# vars
	##############################
	
	git_url="https://github.com/joyent/node"
	git_dir="$HOME/node"

	###############################
	# prereqs
	###############################
 
	echo -e "\n==> Installing prerequisite packages\n"
	sudo apt-get install git-core curl build-essential openssl libssl-dev
 
 	###############################
	# Eval git dir
	###############################
	
	echo -e "\n==> Cloning github repository"
	sleep 1s
	
	# If git folder node exists, evaluate it
	# Avoiding a download again is much desired.
	# If the DIR is already there, the fetch info should be intact
	if [[ -d "$git_dir" ]]; then
		
		echo -e "\nGit folder already exists! Attempting git pull...\n"
		sleep 1s
		# attempt to pull the latest source first
		cd $git_dir
		# eval git status
		output=$(git pull $git_url)

		# evaluate git pull. Remove, create, and clone if it fails
		if [[ "$output" != "Already up-to-date." ]]; then
			echo -e "\nGit directory pull failed. Removing and cloning...\n"
			sleep 2s
			cd
			rm -rf "$git_dir"
			# clone
			git clone "$git_url"
		fi
	else
		echo -e "\nGit directory does not exist. cloning now...\n"
		cd
		sleep 2s
		# clone
		git clone "$git_url"
	fi
	
	# enter git dir if we are not already
	cd $git_dir

	############################
	# Begin nodejs build eval
	############################
	
	# eval clause
	nodejs_check=$(ls "$git_dir")
	
	if [[ "$nodejs_check" != "" ]]; then
		
		echo -e "\n==INFO=="
		echo -e "It seems NodeJS is already built in $git_dir"
		echo -e "Would you like to rebuild [y], or [n]?\n"
		
		# the prompt sometimes likes to jump above sleep
		sleep 0.5s
		
		# gather user input
		read -ep "Choice: " user_input_nodejs
		
		if [[ "$user_input_nodejs" == "n" ]]; then
			echo -e "\n==> Skipping NodeJS build...\n"
			sleep 2s
		elif [[ "$user_input_nodejs" == "y" ]]; then
			echo -e "\n==> Rebuilding NodeJS...\n"
			sleep 2s
			# configure, make, and install
			./configure
			make test
			make
			#sudo make install
		else
			echo -e "\n==ERROR=="
			echo -e "Invalid input, exiting...\n"
			sleep 2s
			exit
		fi
	else	
		echo -e "\nNodeJS does not appear to be built. Building. This will take some time...\n"
		echo -e "Building now...\n"
		sleep 2s
		# configure, make, and install
		./configure
		make test
		make
		#sudo make install

	# end nodejs build eval
	fi
	
	# check that everything installed
	node_check=$(which node)
	
	if [[ "$node_check" == "/usr/bin/node" ]]; then
		echo -e "\nNode.Js installed!\n"
	else
		echo -e "Installation failure!"
	fi
 
	# NPM is packaged with Node.js source so this is now installed too
	# curl http://npmjs.org/install.sh | sudo sh

	# exit back to scriptdir
	cd $scriptdir

}

# start script
install_nodejs
