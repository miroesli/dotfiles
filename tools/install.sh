#!/bin/sh
# Example from https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh
# Requires grep and find for copying, and stow and ln for creating links
# Assumes that grep, find and ln are already installed currently
#
# Script can be run in 3 ways:
# curl: sh -c "$(curl -fsSL https://raw.githubusercontent.com/miroesli/dotfiles/master/tools/install.sh)"
# wget: sh -c "$(wget -qO- https://raw.githubusercontent.com/miroesli/dotfiles/master/tools/install.sh)"
# fetch: sh -c "$(fetch -o - https://raw.githubusercontent.com/miroesli/dotfiles/master/tools/install.sh)"
# 
# Respects the following environment variables:
#   DOTFILES - Path to the dotfiles repository folder (default: $HOME/.dotfiles)
#   BASEDIR  - The base directory of the installation script
#   REPO     - name of the GitHub repo to install from (default: miroesli/dotfiles)
#   REMOTE   - full remote URL of the git repo to install (default: GitHub via HTTPS)
#   BRANCH   - branch to check out immediately after install (default: master)
#
# Other options:
#   BACKUP     - 'no' means the installer will not replace an existing configuration (default: yes)
#   LINK       - 'yes' means the installer will create links instead of copying the files (default: no)
#   VERBOSE	   - 'yes' means the installer will display a detailed output (default: no)
#
# You can also pass some arguments to the install script to set some these options:
#   --no-backup: sets BACKUP to 'no'
#   --link: sets LINK to 'yes'
#   --verbose: sets VERBOSE to 'yes'
# For example:
#   sh install.sh --verbose
# or:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/miroesli/dotfiles/master/tools/install.sh)" "" --verbose
#

exclude_configs=(
	i3blocks
	i3status
)

exclude_dots=(
	.bashrc
	.gitconfig
)

# Default settings
DOTFILES=${DOTFILES:-$HOME/.dotfiles}
# BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../ && pwd)"
REPO=${REPO:-miroesli/dotfiles}
REMOTE=${REMOTE:-https://github.com/${REPO}.git}
BRANCH=${BRANCH:-master}

# Other options
BACKUP=${KEEP_CONFIGS:-yes}
LINK=${LINK:-no}
VERBOSE=${VERBOSE:-no}

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

error() {
	echo ${RED}"Error: $@"${RESET} >&2
}

setup_dotfiles() {
	# Prevent the cloned repository from having insecure permissions. Failing to do
	# so causes compinit() calls to fail with "command not found: compdef" errors
	# for users with insecure umasks (e.g., "002", allowing group writability). Note
	# that this will be ignored under Cygwin by default, as Windows ACLs take
	# precedence over umasks except for filesystems mounted with option "noacl".
	umask g-w,o-w

	echo "${BLUE}Cloning miroesli/dotfiles...${RESET}"

	command_exists git || {
		error "git is not installed"
		exit 1
	}

	git clone -c core.eol=lf -c core.autocrlf=false \
		-c fsck.zeroPaddedFilemode=ignore \
		-c fetch.fsck.zeroPaddedFilemode=ignore \
		-c receive.fsck.zeroPaddedFilemode=ignore \
		--depth=1 --branch "$BRANCH" "$REMOTE" "$DOTFILES" || {
		error "git clone of miroesli/dotfiles repo failed"
		exit 1
	}

	echo
}

setup_colors() {
	# Only use colors if connected to a terminal
	if [ -t 1 ]; then
		RED=$(printf '\033[31m')
		GREEN=$(printf '\033[32m')
		YELLOW=$(printf '\033[33m')
		BLUE=$(printf '\033[34m')
		BOLD=$(printf '\033[1m')
		RESET=$(printf '\033[m')
	else
		RED=""
		GREEN=""
		YELLOW=""
		BLUE=""
		BOLD=""
		RESET=""
	fi
}

setup_dotconfigs() {
	# Select, install, and update configs for packages
	for config in ${CONFIGS[@]}; do
		# if config not excluded then install
		if ! [[ ${exclude_configs[*]} =~ (^|[[:space:]])"$config"($|[[:space:]]) ]]; then
			# Backup or remove package
			if [ ${BACKUP} = yes ]; then
				if [ -d $HOME/.config/$config ]; then
					echo "${YELLOW}Found old ${config} config. Backing up to ~/.config/${config}-$(date +%Y-%m-%d_%H-%M-%S).bak.${RESET}"
					OLD_CONFIG="$HOME/.config/${config}-$(date +%Y-%m-%d_%H-%M-%S).bak"
					mv $HOME/.config/$config "$OLD_CONFIG"
				fi
			else
				if [ -d $HOME/.config/$config ]; then
					echo "${RED}Removing $HOME/.config/$config${RESET}"
					rm -r $HOME/.config/$config
				fi
			fi
			# Create directory if it doesn't already exist
			mkdir -p $HOME/.config/$config
			# Link or copy package
			printf "$BLUE"
			if [ ${LINK} = yes ]; then
				stow -vt $HOME/.config/$config -d ${DOTFILES}/configs/$dotname/.config -S $config
			else
				if [ ${VERBOSE} = yes ]; then
					echo "Copying ${config}: ${DOTFILES}/configs/$dotname/.config/${config} --> $HOME/.config/${config}"
				fi
				cp -r ${DOTFILES}/configs/$dotname/.config/$config $HOME/.config
			fi
			printf "$RESET"
		fi
	done
}

# Future work
# setup_fonts() {}
# setup_gtk() {}

setup_dots() {
	# Select and update dots
	for dot in ${DOTS[@]}; do
		# if config not excluded then install
		if ! [[ ${exclude_dots[*]} =~ (^|[[:space:]])"$dot"($|[[:space:]]) ]]; then
			# Backup or remove file
			if [ ${BACKUP} = yes ]; then
				if [ -f $HOME/$dot ] || [ -h $HOME/$dot ]; then
					echo "${YELLOW}Found old ${dot} file. Backing up to ~/${dot}-$(date +%Y-%m-%d_%H-%M-%S).bak.${RESET}"
					OLD_DOT="$HOME/${dot}-$(date +%Y-%m-%d_%H-%M-%S).bak"
					mv $HOME/$dot $OLD_DOT
				fi
			else
				if [ -f $HOME/$dot ] || [ -h $HOME/$dot ]; then
					echo "${RED}Removing $HOME/$dot${RESET}"
					rm $HOME/$dot
				fi
			fi
			# Link or copy file
			printf "$BLUE"
			if [ ${LINK} = yes ]; then
				echo ${DOTFILES}/configs/$dotname/$dot $HOME/$dot
				ln ${DOTFILES}/configs/$dotname/$dot $HOME/$dot
			else
				if [ ${VERBOSE} = yes ]; then
					echo "Copying ${dot}: ${DOTFILES}/configs/$dotname/${dot} --> $HOME/${dot}"
				fi
				cp ${DOTFILES}/configs/$dotname/$dot ~
			fi
			printf "$RESET"
		fi
	done
}

main() {
	# Parse arguments
	while [ $# -gt 0 ]; do
		case $1 in
			--no-backup) BACKUP=no ;;
			--link) LINK=yes ;;
			--verbose) VERBOSE=yes ;;
		esac
		shift
	done

	# setup colors for output
	setup_colors

	# print backup and link parameters selected
	if [ ${VERBOSE} = yes ]; then
		echo "${BOLD}BACKUP: ${BACKUP}, LINK: ${LINK}" 
	fi

	if [ ${LINK} = yes ]; then
		command_exists stow || {
			error "stow is not installed"
			exit 1
		}
	fi

	if ! [ -d "$DOTFILES" ]; then
		echo "${GREEN}Cloning dotfiles...${RESET}"
		setup_dotfiles
	fi
	printf "$RESET"
	
	read -p 'Dotfile name: ' dotname
	if [ -d ${DOTFILES}/configs/$dotname ]; then
		echo "${GREEN} Installing $dotname...${RESET}"
	else
		echo "${RED}Dotfile \"$dotname\" doesn't exist."
		echo "Select one of the following:${RESET}"
		find "${DOTFILES}"/configs/* -maxdepth 0 -type d -printf "%f\n"
        exit 1
	fi

	CONFIGS=$(find "${DOTFILES}"/configs/$dotname/.config/* -maxdepth 0 -type d -printf "%f\n")
	DOTS=$(find "${DOTFILES}"/configs/$dotname/ -type f -name ".[^.]*" -printf "%f\n")

	if [ ${VERBOSE} = yes ]; then
		echo $CONFIGS
		echo $DOTS
	fi

	# Future work to add selecting package and dot exclusions
	setup_dotconfigs
	setup_dots
	echo "${GREEN}Done... Configs Installed!${RESET}"
}

main "$@"
