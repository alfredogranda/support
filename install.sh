#!/bin/bash

#--------------------------------------------------------------
# @author Alfredo Granda
#
# Installer script to install a software development env
# on OSX Sierra.
#
# Make the file executable by
# running the following:
#
# chmod +x install.sh
#--------------------------------------------------------------

#--------------------------------------------------------------
# BREWS TO INSTALL
#--------------------------------------------------------------
declare -a BREWS=(
	'wget'
	'python'
	'git'
	'node'
	'composer'
	'awscli'
	'aws-elasticbeanstalk'
	'mysql'
	'httpd24 --with-privileged-ports --with-http2'
	'php56 --with-httpd24'
	'php70 --with-httpd24'
	'php71 --with-httpd24'
	'php56-xdebug'
	'php70-xdebug'
	'php71-xdebug'
	'xdebug-osx'
	'redis'
);

#--------------------------------------------------------------
# CASKS TO INSTALL
#--------------------------------------------------------------
declare -a CASKS=(
	'sublime-text' 
	'google-chrome' 
	'phpstorm' 
	'spectacle' 
	'postman' 
	'java'
	'mysqlworkbench'
	'slack'
	'tunnelblick'
	'virtualbox'
	'poedit'
	'android-studio'
);

#--------------------------------------------------------------
# COLORS
#--------------------------------------------------------------
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
SILVER="\033[0;37m"
GRAY="\033[0;30m"
NC="\033[0m" # No Color

#
# CONSOLE MESSAGES
#--------------------------------------------------------------
function __msg { echo -e "${1}${2}${NC}"; }
function msg { __msg ${NC} "${1}"; }
function warn { __msg ${YELLOW} "${1}"; }
function error { __msg ${RED} "${1}"; }
function info { __msg ${CYAN} "${1}"; }
function success { __msg ${GREEN} "${1}"; }
function msgline { __msg ${NC} "------------------------------------------------"; }

#
# ENSURE FILE EXISTS. IF IT DOES NOT THEN IT CREATES IT
#--------------------------------------------------------------
function makeSureAFileExists {
	if [[ ! -f ${1} ]]; then touch ${1}; fi
}

#
# Determine if a file has a specific line
#
# fileHasLine {filename} {searchRegex}
#--------------------------------------------------------------
function fileHasLine {
	if [[ -z $(grep -ix "${2}" ${1}) ]]; then echo "0"; else echo "1"; fi
}

#
# Add a line if it is not already present
#
# addLineIfNotPresent {filename} {searchRegex} {lineToAdd}
#--------------------------------------------------------------
function addLineIfNotPresent {
	if [ $(fileHasLine ${1} "${2}") -eq 0 ]; then
		echo -e ${3} >> ${1}
	fi 
}

#
# Determine if the brew package or brew cask package is
# installed.
#
# You may send the module as "cask" to check for cask
# packages like: packageInstalled "sublime-text" "cask"
#
# packageInstalled {packageName} {module}
#--------------------------------------------------------------
function packageInstalled {
	pkg=${1}
	module=${2}
	if brew ${module} list -1 | grep -q "^${pkg}\$"; then
		echo "1"
	else
		echo "0"
	fi
}

#
# INSTALL OR UPDATE BREW
#--------------------------------------------------------------
function install_brew {
	msgline
	which -s brew
	if [[ $? != 0 ]] ; then
		info "Installing Brew"
		/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	else
		info "Updating Brew"
		brew update
	fi
}

#
# ADD ALIASES TO YOUR BASH_PROFILE
#--------------------------------------------------------------
function install_bash_profile {
	bashFile=~/.bash_profile
	msgline
	info "Updating ${bashFile}"
	makeSureAFileExists ${bashFile}

	addLineIfNotPresent ${bashFile} "^alias showFiles.*$" "alias showFiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'"
	addLineIfNotPresent ${bashFile} "^alias hideFiles.*$" "alias hideFiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'"
	addLineIfNotPresent ${bashFile} "^alias addDockSpace.*$" "alias addDockSpace='defaults write com.apple.dock persistent-apps -array-add '\"'\"'{\"tile-type\"=\"spacer-tile\";}'\"'\"'; killall Dock'"
	addLineIfNotPresent ${bashFile} "^alias myip.*$" "alias myip='echo \"Local IP:\";ipconfig getifaddr en0;echo \"Public IP:\";curl ipecho.net/plain;echo'"
	addLineIfNotPresent ${bashFile} "^alias apr.*$" "alias apr='sudo apachectl -k restart'"
	addLineIfNotPresent ${bashFile} "^alias myr.*$" "alias myr='mysql.server restart'"
	addLineIfNotPresent ${bashFile} "^alias checkport.*$" "alias checkport='sudo lsof -i :80 # checks port 80'"
	addLineIfNotPresent ${bashFile} "^export PATH.*$" "export PATH=~/.composer/vendor/bin:\$PATH"
}

#
# Before installing or updating git
#--------------------------------------------------------------
function preAlways_git {
	if [ -f ~/.gitconfig ]; then
		success "Downloading git config to ~/.gitconfig"
		wget -O ~/.gitconfig https://raw.githubusercontent.com/papaya-holdings/global/master/dot-files/.gitconfig
	fi
}

#
# After installing mysql
#--------------------------------------------------------------
function post_mysql {
	brew services start mysql
	warn "*************************************************************************"
	warn " STARTING MYSQL SETUP USER INPUT REQUIRED (CURRENT PASSWORD IS EMPTY)"
	warn "*************************************************************************"
	mysql_secure_installation
}

#
# After installing node
#--------------------------------------------------------------
function post_node {
	npm install -g less
	gem install sass
	npm install -g bower
}

#
# Before installing composer
#--------------------------------------------------------------
function pre_composer {
	# Make sure we have all the taps
	brew tap homebrew/dupes
	brew tap homebrew/versions
	brew tap homebrew/php
}

#
# After installing composer
#--------------------------------------------------------------
function post_composer {
	composer global require "laravel/installer"
}

#
# Before installing httpd24
#--------------------------------------------------------------
function pre_httpd24 {
	# Make sure we have all the taps
	brew tap homebrew/dupes
	brew tap homebrew/versions
	brew tap homebrew/apache
	
	# Stop Apple apache
	warn "Stopping current httpd. Please enter your password"
	sudo apachectl stop
	# Make sure that we remove the Apple service for apache
	sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null
}

#
# After installing httpd24
#--------------------------------------------------------------
function post_httpd24 {
	
	# Make sure that apache runs on startup
	sudo cp -v $(brew --prefix httpd24)/homebrew.mxcl.httpd24.plist /Library/LaunchDaemons
	sudo chown -v root:wheel /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist
	sudo chmod -v 644 /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist
	sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist

	# Make a directory for additional configurations
	if [[ ! -d /usr/local/etc/apache2/2.4/other ]]
	then
		success "Creating folder for configs at /usr/local/etc/apache2/2.4/other"
		mkdir /usr/local/etc/apache2/2.4/other
	fi

	# Make sure that we have the php handlers set on apache
	if [[ ! -f /usr/local/etc/apache2/2.4/other/php.conf ]]
	then
		success "Adding php handlers to apache at /usr/local/etc/apache2/2.4/other/php.conf"
		echo -e "<FilesMatch \\.php$>\n\tSetHandler application/x-httpd-php\n</FilesMatch>\n\n<IfModule dir_module>\n\tDirectoryIndex index.html index.php\n</IfModule>" > /usr/local/etc/apache2/2.4/other/php.conf
	fi

	# Get the configuration settings for httpd.conf
	APACHE_CONF_FILE=`httpd -V | grep -i server_config_file | cut -d '"' -f 2`
	IAM=`whoami`

	# Append settings to the httpd.conf file
	success "Upgrading ${APACHE_CONF_FILE}"
	if ! grep -qFx "ServerName 127.0.0.1" ${APACHE_CONF_FILE}; then echo "ServerName 127.0.0.1" >> ${APACHE_CONF_FILE}; fi
	if ! grep -qFx "Listen 80" ${APACHE_CONF_FILE}; then echo "Listen 80" >> ${APACHE_CONF_FILE}; fi
	if ! grep -qFx "Listen 443" ${APACHE_CONF_FILE}; then echo "Listen 443" >> ${APACHE_CONF_FILE}; fi
	if ! grep -qFx "LoadModule socache_shmcb_module libexec/mod_socache_shmcb.so" ${APACHE_CONF_FILE}; then echo "LoadModule socache_shmcb_module libexec/mod_socache_shmcb.so" >> ${APACHE_CONF_FILE}; fi
	if ! grep -qFx "LoadModule ssl_module libexec/mod_ssl.so" ${APACHE_CONF_FILE}; then echo "LoadModule ssl_module libexec/mod_ssl.so" >> ${APACHE_CONF_FILE}; fi
	if ! grep -qFx "Listen 443" ${APACHE_CONF_FILE}; then echo "LoadModule rewrite_module libexec/mod_rewrite.so" >> ${APACHE_CONF_FILE}; fi
	if ! grep -qFx "User ${IAM}" ${APACHE_CONF_FILE}; then echo "User ${IAM}" >> ${APACHE_CONF_FILE}; fi
	if ! grep -qFx "Group staff" ${APACHE_CONF_FILE}; then echo "Group staff" >> ${APACHE_CONF_FILE}; fi
	if ! grep -qFx "IncludeOptional /usr/local/etc/apache2/2.4/other/*.conf" ${APACHE_CONF_FILE}; then echo "IncludeOptional /usr/local/etc/apache2/2.4/other/*.conf" >> ${APACHE_CONF_FILE}; fi

	# Download the vhost script
	if [[ ! -f /usr/local/bin/vhost ]]
	then
		success "Installing vhost"
		curl -L https://raw.githubusercontent.com/papaya-holdings/global/master/bash-scripts/vhost > /usr/local/bin/vhost
		chmod +x /usr/local/bin/vhost
	fi

	# Create the sites and a test web app
	if [[ ! -d ~/Sites ]]
	then
		success "Creating ~/Sites directory"
		mkdir ~/Sites
	fi
	if [[ ! -d ~/Sites/test ]]
	then
		success "Creating ~/Sites/test directory"
		mkdir ~/Sites/test
		echo "<?php phpinfo();" > ~/Sites/test/index.php
	fi
	
	# Run vhost in case the apache has been reinstalled
	success "Creating vhost for ~/Sites/test"
	curdir=`pwd`
	cd ~/Sites/test
	vhost
	cd "${curdir}"

	# Restart apache and open site
	msg "Restarting httpd to apply changes"
	sudo apachectl -k restart
	open https://test.local.vh
}

#
# Helper to unlink the current php version
#--------------------------------------------------------------
function unlink_current_php {
	currentversion=$(php -r "error_reporting(0); echo str_replace('.', '', substr(phpversion(), 0, 3));")
	warn "Unlinking php version ${currentversion}"
    brew unlink php${currentversion} 2> /dev/null > /dev/null

	majorOld=${currentversion:0:1}

	# Lets comment the LoadModule directive
	apacheConf=`httpd -V | grep -i server_config_file | cut -d '"' -f 2`
	warn "Disabling LoadModule php${majorOld}_module in ${apacheConf}"
	sudo sed -i -e "/LoadModule php${majorOld}_module/s/^#*/#/" $apacheConf
}

#
# Helper to add php.ini settings to the current php version
#--------------------------------------------------------------
function add_php_ini_settings {
	# Get the ini file
	iniFile=$(php --ini | grep -i "loaded conf" | cut -d ':' -f 2 | tr -d '[:space:]')

	# Make sure the date.timezone is set
	success "Setting date.timezone to ${iniFile}"
    if ! grep -qFx "date.timezone = UTC" ${iniFile}; then echo "date.timezone = UTC" >> ${iniFile}; fi

    # Restart apache
    sudo apachectl -k restart
}

#
# Before installing php versions
#--------------------------------------------------------------
function pre_php56 { unlink_current_php; }
function pre_php70 { unlink_current_php; }
function pre_php71 { unlink_current_php; }

#
# After installing php versions
#--------------------------------------------------------------
function post_php56 { add_php_ini_settings; }
function post_php70 { add_php_ini_settings; }
function post_php71 { add_php_ini_settings; }

#
# Helper to install sphp (PHP Switcher for brew)
#--------------------------------------------------------------
function install_sphp {
	if [[ ! -f /usr/local/bin/sphp ]]; then
		curl -L https://gist.github.com/w00fz/142b6b19750ea6979137b963df959d11/raw > /usr/local/bin/sphp
		chmod +x /usr/local/bin/sphp
	fi
}

#
# Before installing xdebug for php versions
#--------------------------------------------------------------
function pre_php56-xdebug {
	install_sphp
	currentversion=$(php -r "error_reporting(0); echo str_replace('.', '', substr(phpversion(), 0, 3));")
	sphp 56
}
function pre_php70-xdebug {
	install_sphp
	currentversion=$(php -r "error_reporting(0); echo str_replace('.', '', substr(phpversion(), 0, 3));")
	sphp 70
}
function pre_php71-xdebug {
	install_sphp
	currentversion=$(php -r "error_reporting(0); echo str_replace('.', '', substr(phpversion(), 0, 3));")
	sphp 71
}

#
# INSTALL ALL OF THE PROVIDED BREW PACKAGES
#
#  This will recieve as first parameter an array with
#  the list of packages to install. The packages can
#  contain the options for the brew installation like
#    php56 --with-httpd24
#
#  For 'cask' packages set the 'module' param to 'cask'
#
# install_brew_packages {packages_array} {module}
#--------------------------------------------------------------
function install_brew_packages {
	# Get the parameters
	declare -a packages=("${!1}")
	module=${2} # empty or cask

	for fullPackageName in "${packages[@]}"; do

		# Extract the parts of the package name
		packName=$( echo ${fullPackageName} | cut -f 1 -d " " )
		packOptionsStr=$( echo ${fullPackageName} | cut -f 2- -d " " )
		if [[ "${packName}" == "${packOptionsStr}" ]]; then packOptionsStr=""; fi
		IFS=' ' read -a packOptions <<< "${packOptionsStr}"
		
		# Make the function names to call
		FNC_PRE_ALREADY_INSTALLED="preAlways${module}_${packName}"
		FNC_PRE="pre${module}_${packName}"
		FNC_POST_ALREADY_INSTALLED="postAlways${module}_${packName}"
		FNC_POST="post${module}_${packName}"
		
		# Show start message	
		msgline
		info "Starting${module} ${packName}"

		# Determine if the package is installed and if it has the correct packages
		alreadyInstalled=$(packageInstalled ${packName} ${module})

		# Check if the current installation contains all of the required package options
		installedWithAllOptions="1"
		if [[ ${alreadyInstalled} == "1" && ${module} != "cask" ]]; then
			usedops=$(brew info ${packName} --json=v1 | perl -nle 'm/used_options":\[([^]]*)\]/; print $1' | sed 's/"//g' | sed 's/,/ /g')
			for requiredOptionName in "${packOptions[@]}"; do
				if [[ ${usedops} != *${requiredOptionName}* ]]; then
					error "This package was installed without the ${requiredOptionName} so we will remove it"
					installedWithAllOptions="0"
				fi
			done
		fi

		# Uninstall the package if it has not got all the options
		if [[ ${installedWithAllOptions} != "1" ]]; then
			brew uninstall ${packName} --ignore-dependencies
			alreadyInstalled="0"
			installedWithAllOptions="1"
		fi
		
		# Run the pre always function
		type_of_function=$(type -t ${FNC_PRE_ALREADY_INSTALLED})
		if [ ! -z ${type_of_function} ]
		then
			warn "Running custom function ${FNC_PRE_ALREADY_INSTALLED}"
			${FNC_PRE_ALREADY_INSTALLED} ${packName} ${packOptionsStr}
		fi

		# Run the pre function only if NOT installed
		if [[ ${alreadyInstalled} == "0" ]]; then
			type_of_function=$(type -t ${FNC_PRE})
			if [ ! -z ${type_of_function} ]
			then
				warn "Running custom function ${FNC_PRE} before installing"
				${FNC_PRE} ${packName} ${packOptionsStr}
			fi
		fi

		# Install the package
		if [[ ${alreadyInstalled} == "0" ]]; then
			brew ${module} install ${fullPackageName}
			success "brew ${module} ${fullPackageName}: Installed"
		else
			success "brew ${module} ${fullPackageName}: Already installed"
		fi

		# Run the post function only if RECENTLY INSTALLED
		if [[ ${alreadyInstalled} == "0" ]]; then
			type_of_function=$(type -t ${FNC_POST})
			if [ ! -z ${type_of_function} ]
			then
				warn "Running custom function ${FNC_POST} after installing"
				${FNC_POST} ${packName} ${packOptionsStr}
			fi
		fi

		## Run the post always function
		type_of_function=$(type -t ${FNC_POST_ALREADY_INSTALLED})
		if [ ! -z ${type_of_function} ]
		then
			warn "Running custom function ${FNC_POST_ALREADY_INSTALLED}"
			${FNC_POST_ALREADY_INSTALLED} ${packName} ${packOptionsStr}
		fi

	done
}

#
# MAIN
#--------------------------------------------------------------
install_bash_profile
install_brew
install_brew_packages BREWS[@]
install_brew_packages CASKS[@] "cask"
