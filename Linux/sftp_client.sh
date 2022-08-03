#!/bin/bash
################################################################################
##
##      sftp_client.sh
##
################################################################################

ImportConfig () {
############################################################################
### ImportConfig - Purpose is to import the config file for script use
############################################################################

#Check if arguments are passed in, if not prompt the user
if [ $# = 0 ]
	then
		printf "Please provide arguments\n"
		WelcomeScreen
	else
		for argument in $*; do
			case $argument in
				'-c')  
					config_path=`echo $* | sed -e 's/.*-c //' | sed -e 's/ -.*//g'` ;;
				'-h') 
					WelcomeScreen ;; 
				\?) printf "\nERROR:  \"$argument\" is not a valid argument.\n"
					WelcomeScreen ;;
			esac
		done
fi

unset argument

#Attempt to pull the sftp config file, leave the rest for other functions, must get logging up and running first and foremost
#Determine if custom config path is set, if not set a default path and import, if it
if [[ -z ${config_path} ]]; then
	config_path=/opt/sftp_client/sftp_client.conf
	if [[ -r ${config_path} ]]; then
		#Import configuration file, default is /opt/sftp_client/sftp_client.conf unless otherwise specified
		source ${config_path}
	else
		printf "/opt/sftp_client_sftp_client.conf does not exist or is not readable, exiting...\n"
		exit 1
	fi
else
	if [[ -r ${config_path} ]]; then
		#Import configuration file, default is /opt/sftp_client/sftp_client.conf unless otherwise specified
		source ${config_path}
	else
		printf "${config_path} does not exist or is not readable, exiting...\n"
		exit 1
	fi
fi
}

ImportGlobalFunctions () {
############################################################################
### ImportGlobalFunctions - Purpose is to import needed functions
############################################################################
#Define script execution directory for Importing Global Functions
script_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DebugLogging "Script directory is ${script_dir}"

#Importing functions
for func_file in ${script_dir}/funcs/*.func; do
	source ${func_file}
done

}

WelcomeScreen () {
############################################################################
### WelcomeScreen - Purpose is to show usage of script to user
############################################################################

if [[ $# -eq 0 ]]; then
	  printf "Usage: %s <-get | -put> -s <path_to_files> -t <target_dir> [-c <path_to_conf>] [-e <email_addres>] [-u <user>] [-ip <ip_address>] [-port <port>] [-date] [-h] \n"
	  printf "       -get  Pull files locally from an sFTP server\n"
	  printf "       -put  Put local files to an sFTP server\n"
	  printf "       -s    Location of source files to be moved - ex. /reports/output/* \n"
	  printf "       -t    Target directory where the files should be transferred to - ex. /reports/destination/ \n"
	  printf "Optional:\n"
	  printf "       -c    Location for custom configuration file - ex. /etc/custom_sftp_client.conf\n"
	  printf "       -e    Specifies an email address to use for error logs to be sent\n"
	  printf "       -u    Username for sftp server - only optional if public key authentication is setup\n"
	  printf "       -ip   IP address of sftp server - only optional if configured in sftp_client.conf\n"
	  printf "       -port Port sftp server is listening on - only optional if configured in sftp_client.conf\n"
	  printf "       -date Insert date at the end of the file\n"
	  printf "       -h    Prints this usage menu.\n"
	  exit 0
fi	 
}

ProcessInputSwitches () {
############################################################################
### ProcessInputSwitches - Purpose is to process user provided arguments
############################################################################

#Ensure all flags are set as necessary
if [ $# = 0 ]
	then
		printf "Please provide arguments\n"
		Welcome_Screen
	else
		for argument in $*; do
			case $argument in
				'-get') 
					get='y'
					get_or_put='get'
					DebugLogging "Sepcified ${get_or_put}!" ;;
				'-put') 
					put='y'
					get_or_put='put'
					DebugLogging "Specified ${get_or_put}!" ;;
				'-s') 
					source_files=`echo $* | sed -e 's/.*-s //' | sed -e 's/ -.*//g'`
					source_files=(${source_files})
					source_path=`dirname ${source_files[0]}`
					DebugLogging "Source files is ${source_files[*]}" 
					DebugLogging "Number of objects in source files is ${#source_files[@]}"
					DebugLogging "Source path is ${source_path}" ;;
				'-t') 
					target_path=`echo $* | sed -e 's/.*-t //' | sed -e 's/ -.*//g'`
					inbound_backupdir=${target_path}/received
					DebugLogging "Target path is ${target_path}"
					DebugLogging "The inbound backup directory is ${inbound_backupdir}" ;;
				'-c') 
					#Config Path is set via ImportConfig function, using this for debug logging on where config file is set
					DebugLogging "Custom config file is ${config_path}" ;;
				'-e') 
					email_address='y'
					email_recipients=`echo $* | sed -e 's/.*-e //' | sed -e 's/ -.*//g'` 
					DebugLogging "Emails set to be sent to ${email_recipients}" ;;
				'-u') 
					custom_user='y'
					sftp_user=`echo $* | sed -e 's/.*-u //' | sed -e 's/ -.*//g'` 
					DebugLogging "Custom username is ${sftp_user}" ;;
				'-ip') 
					custom_ip='y' 
					sftp_ip=`echo $* | sed -e 's/.*-ip //' | sed -e 's/ -.*//g'` 
					DebugLogging "Custom SFTP IP is ${sftp_ip}";;
				'-port') 
					custom_port='y' 
					sftp_port=`echo $* | sed -e 's/.*-port //' | sed -e 's/ -.*//g'` 
					DebugLogging "Custom SFTP Port is ${sftp_port}" ;;
				'-date') 
					insert_date='y' 
					DebugLogging "Insert date in file name added!" ;;
				'-h') 
					WelcomeScreen ;; 
				\?) printf "\nERROR:  \"$argument\" is not a valid argument.\n"
					WelcomeScreen ;;
			esac
		done
fi

#Make modular, unset variables no longer needed
unset argument
}



ScriptChecks () {
############################################################################
### ScriptChecks = Purpose is to pre-check all host config is in place prior to running
############################################################################
#Check that SFTP is setup correctly
SFTPCheck
CaptureExitCode
VerifyExitCode
FailCheckExitClean

#Check that Email functionality is setup, but only if email recipients are defined
if [[ ! -z ${email_recipients} ]]; then
	EmailCheck
	CaptureExitCode
	VerifyExitCode
	FailCheckExitClean
fi

}

GetSourceFiles () {
#Populate the source_files array if this is a get run
if [[ ${get_or_put} == 'get' ]]; then
	TestBatchDir
	echo "cd ${source_path}
ls
exit">${sftp_batch}
	if CallSFTP ${sftp_ip} ${sftp_port} ${sftp_batch} ${sftp_user}; then
		TraceLogging "Defining source file array for get process..."
		#Define temporary file for redirecting output to build array for get files
		get_temp=`mktemp ${sftp_batchdir}/sftp_get_temp$(date +_%Y-%m-%d_%H%M%S)_XXXXXXXXXX.dat`
		DebugLogging "Calling sftp with /usr/bin/sftp -b ${sftp_batch} -oPort=${sftp_port} ${sftp_user}@${sftp_ip} >${get_temp} 2>&1"
		/usr/bin/sftp -b ${sftp_batch} -oPort=${sftp_port} ${sftp_user}@${sftp_ip} >${get_temp} 2>&1
		VerifyExitCode "Unable to successfully call sftp with /usr/bin/sftp -b ${sftp_batch} -oPort=${sftp_port} ${sftp_user}@${sftp_ip} >${get_temp} 2>&1"
		source_files=(`cat ${get_temp} | grep -v 'sftp>'`)
		TraceLogging "Source files are now set to ${source_files[*]}"
		#Remove get temp variable since source_files is now populated
		DebugLogging "Removing temporary file ${get_temp}..."
		rm -f ${get_temp}
		CaptureExitCode
		VerifyExitCode "Unable to remove ${get_temp}"
		TraceLogging "Successfully removed ${get_temp}"
		unset get_temp
	else
		FatalLogging "Unable to test sftp for get process. Exiting..."
		CleanupBatch
		EmailFile "${email_recipients}" "${log_instance_file}" "SFTP transfer on `hostname` has failed!"
		DebugLogging "Ending script!"
		CleanupInstanceLog
		exit 1
	fi
fi
}

PutAssignBackupDir () {
#Only assign outbound backup dir if it's a put
if [ ${get_or_put} = 'put' ]; then
	outbound_backupdir=`echo "${source_path}/sent/"`
	DebugLogging "The outbound backup direcotry is ${outbound_backupdir}" 
else
	DebugLogging "Script is set to get mode, no need to assign a put backup dir"
fi
}

CheckGlobalVariables () {
############################################################################
### CheckGlobalVariables - Purpose is to sanity check variables
############################################################################

#Exit if neither get nor put are specified
if [[ -z ${get_or_put} ]]; then
	StandardLog "Neither -get nor -put were set, exiting..."
	echo ""
	WelcomeScreen
else
	DebugLogging "${get_or_put} was set, continuing!"
fi

#Exit if both get and put are specified
if [[ ${get} && ${put} ]]; then
	StandardLog "Both -get and -put were set, exiting..."
	echo ""
	WelcomeScreen
fi

#Ensure required switches are specified
if [[ ${source_files[*]} ]] ; then
	#If this is a put - check to see if any files exist / the wildcard variable isn't translated
	if [[ "${get_or_put}" == 'put' ]]; then
		ls ${source_files[*]} > /dev/null 2>&1
		CaptureExitCode
		#If no file exists as passed in, that's fine just exit 0 and alert the debug log
		if [ "$EXITCODE" != "0" ] ; then
			DebugLogging "No files exist that were requested to transfer: ${source_files[*]}."
			RemoveInstanceLog
			exit 0
		fi
	fi
else
	StandardLog "Required argument -s not specified, exiting..."
	echo ""
	WelcomeScreen
fi

if [[ ${sftp_batchdir} ]]; then
	DebugLogging "The sftp batch direcotry is ${sftp_batchdir}"
else
	StandardLog "Required element sftp_batchdir is not specified in config file ${config_path}, exiting..."
	echo ""
	WelcomeScreen
fi

if [[ ${target_path} ]]; then
	:
else
	StandardLog "Required argument -t not specified, exiting..."
	echo ""
	WelcomeScreen
fi

#unset variables
unset get
unset put
}

RemoveDirectories () {
############################################################################
### RemoveDirectories - Purpose is to remove directories from list of files
### 	for transfer
############################################################################

#Only call this for a put script
if [[ ${get_or_put} == 'put' ]]; then
	#Purpose of this is to rebuild source_files to remove subdirectories from consideration for transfer

	#Declare an iterator to go through the loop
	loop_iterator=0
	#Determine number of times to iterate
	number_of_iterations=`echo ${#source_files[@]}`
	TraceLogging "Number of iterations for loop is ${number_of_iterations}"

	#While there are objects in the loop, check for directories and filter out what we don't want included in ${source_files[*]}
	while [ ${loop_iterator} -lt ${number_of_iterations} ]; do
		TraceLogging "Current loop iteration is number ${loop_iterator} and contains ${source_files[${loop_iterator}]}"
		#If the object for the loop iteration is a directory
		if [[ -d ${source_files[${loop_iterator}]} ]]; then
			TraceLogging "Found a direcotry, loop iteration ${loop_iterator}, it is ${source_files[${loop_iterator}]}, removing...."
			#Remove this object from the index
			unset source_files[${loop_iterator}]
			#Reindex without the sent directory
			source_files=( "${source_files[@]}" )
			#To ensure all elements are evaluated through the loop, decrement the loop_iterator and number_of_iterations
			let loop_iterator--
			let number_of_iterations--
		fi
	let loop_iterator++
	done

	#Check array after loop
	number_of_iterations=`echo ${#source_files[@]}`
	DebugLogging "After removal of known directories, number of iterations for loop is ${number_of_iterations}, array looks like: ${source_files[@]}"

	#Unset source_file_temp since it will no longer be used and source_file will be used moving forward outside of this functionality
	unset loop_iterator
	unset number_of_iterations
fi
}

CheckSourceFiles () {
#Check to see if source_files is blank, if so, exit success with nothing to move
if [[ -z ${source_files[@]} ]]; then
	InfoLogging "No files to transfer, exiting..."
	CleanupBatch
	CleanupInstanceLog
	ExitSuccess
fi
}

ReplaceSpecChar () {
#############################################################################
### ReplaceSpecChar - Purpose is to identify special characters in file names
### 	and rename files to remove special characters
#############################################################################

#Purpose of this function is to check for and remove special characters from file names as the sftp command does not like them

#Declare an iterator to go through the loop
loop_iterator=0
#Determine number of times to iterate
number_of_iterations=`echo ${#source_files[@]}`
TraceLogging "Number of iterations for loop is ${number_of_iterations}"

#While there are objects in the loop, check for directories and filter out what we don't want included in ${source_files[*]}
while [ ${loop_iterator} -lt ${number_of_iterations} ]; do
	TraceLogging "Current loop iteration is number ${loop_iterator} and contains ${source_files[${loop_iterator}]}"
	#If the object for the loop iteration contains a special character
	if [[ ${source_files[${loop_iterator}]} == *[\!\@#\$\%\^\&\*\(\)+]* ]]; then
		DebugLogging "The following has been identified to have a special character ${source_files[${loop_iterator}]}"
		#If Successful, special character was found, rename the file replacing special character(s) with _
		newfile=`echo "${source_files[${loop_iterator}]}" | /usr/bin/sed 's/[\!\@\?\#\$\%\^\&\*\(\)\\]/_/g'`
		DebugLogging "The new filename without the speical character is ${newfile}"
		#Check if newfile exists, if it does, determine another filename that doesn't and apply it
		if [[ -e ${newfile} ]]; then
			DebugLogging "The new filename already exists, identifying an unused name..."
			#Create variable to iterate on
			iterator=0
			#While loop for as long as the file exists, do the following
			while [[ -e ${newfile}.$iterator ]]; do
				#Iterate the variable for the next test in the loop
				let iterator++
			done
			#Reassign to an available filename
			newfile=`echo "${newfile}.${iterator}"`
			DebugLogging "The new unused filename is ${newfile}"
			#Release iterator from memory
			unset iterator
		fi
		TraceLogging "Loop iteration ${loop_iterator} - Renaming ${source_files[${loop_iterator}]} to ${newfile}"
		#Rename the file, must use quotes so special characters aren't translated and backup to ensure no data loss
		mv -f "${source_files[${loop_iterator}]}" ${newfile}
		CaptureExitCode
		VerifyExitCode "Unable to move ${object} to ${newfile}"
		#Replace pre-named object with new object
		source_files[${loop_iterator}]=${newfile}
		#Remove newfile, no longer needed for this iteration
		unset newfile
		#To ensure all elements are evaluated through the loop, decrement the loop_iterator
		let loop_iterator--
	fi
	let loop_iterator++
done

#Check array after loop
number_of_iterations=`echo ${#source_files[@]}`
DebugLogging "After removal of special characters, number of iterations for loop is ${number_of_iterations}"
DebugLogging "After removal of special characters, the current file array is ${source_files[*]}"

#Unset items for portability
unset loop_iterator
unset number_of_iterations

}

InsertDate () {
#############################################################################
### InsertDate - Purpose is to insert date before file extension
#############################################################################
#Only fire if the user called for it and only run if put is specified
if [[ ${get_or_put} == 'put' ]]; then
	if [[ ${insert_date} == 'y' ]]; then
		#Declare an iterator to go through the loop
		loop_iterator=0
		#Determine number of times to iterate
		number_of_iterations=`echo ${#source_files[@]}`
		TraceLogging "Number of iterations for loop is ${number_of_iterations}"
		TraceLogging "Before updating the array, it looks like: ${source_files[@]}"

		#While there are objects in the loop, check for directories and filter out what we don't want included in ${source_files[*]}
		while [ ${loop_iterator} -lt ${number_of_iterations} ]; do
			TraceLogging "Current loop iteration is number ${loop_iterator} and contains ${source_files[${loop_iterator}]}"
			#Test if a date is already inserted, if so assign 'new_file_name' to be the existing file name and if not add the date in
			if [[ `echo ${source_files[${loop_iterator}]} | grep '[0-9]\{13\}'` != ${source_files[${loop_iterator}]} ]]; then
				#Count how many '.' there are, if there's one period put the date stamp prior to the last period
				TraceLogging "Number of periods in the file name ${source_files[${loop_iterator}]} is `echo ${source_files[${loop_iterator}]} | awk  -F"." '{print NF-1}'`"
				if [[ `echo ${source_files[${loop_iterator}]} | awk  -F"." '{print NF-1}'` == "0" ]]; then
					DebugLogging "No extenstion on file ${source_files[${loop_iterator}]} detected!"
					#No file extension from file name, insert date/time/pid
					new_file_name="${source_files[${loop_iterator}]%.*}_$(date +%Y%m%d%H%M%S)" 
					mv ${source_files[${loop_iterator}]} ${new_file_name}
					DebugLogging "New File name is ${new_file_name}"
					CaptureExitCode
					VerifyExitCode "Could not rename file with date info"
					#Replace old with new entry in array
					source_files[${loop_iterator}]=${new_file_name}				
				elif [[ `echo ${source_files[${loop_iterator}]} | awk  -F"." '{print NF-1}'` == "1" ]]; then
					DebugLogging "Extenstion on file ${source_files[${loop_iterator}]} detected!"
					#Isolate file extension from file name, insert date/time/pid
					new_file_name="${source_files[${loop_iterator}]%.*}_$(date +%Y%m%d%H%M%S).${source_files[${loop_iterator}]##*.}" 
					DebugLogging "New File name is ${new_file_name}"
					mv ${source_files[${loop_iterator}]} ${new_file_name}
					CaptureExitCode
					VerifyExitCode "Could not rename file with date info"
					#Replace old with new entry in array
					source_files[${loop_iterator}]=${new_file_name}
				else
					#If there's more than one period, put the date at the end of the file
					DebugLogging "More than one period on file ${source_files[${loop_iterator}]} detected!"
					#Isolate file extension from file name, insert date/time/pid
					new_file_name="${source_files[${loop_iterator}]}_$(date +%Y%m%d%H%M%S)" 
					DebugLogging "New File name is ${new_file_name}"
					mv ${source_files[${loop_iterator}]} ${new_file_name}
					CaptureExitCode
					VerifyExitCode "Could not rename file with date info"
					#Replace old with new entry in array
					source_files[${loop_iterator}]=${new_file_name}
				fi
			#To ensure all elements are evaluated through the loop, decrement the loop_iterator and number_of_iterations
			let loop_iterator--
			fi
		let loop_iterator++
		done

		TraceLogging "After updating the array, it looks like: ${source_files[@]}"

		#Unset items for portability
		unset loop_iterator
		unset number_of_iterations
	fi
fi
}

TestSourceFile () {
#############################################################################
### TestSourceFile - Purpose is to ensure all files exist prior to transfer
#############################################################################

#Only run for put, should not be needed for get
if [[ ${get_or_put} == 'put' ]]; then
	#Declare an iterator to go through the loop
	loop_iterator=0
	#Determine number of times to iterate
	number_of_iterations=`echo ${#source_files[@]}`
	TraceLogging "Number of iterations for loop is ${number_of_iterations}"

	#While there are objects in the loop, check for directories and filter out what we don't want included in ${source_files[*]}
	while [ ${loop_iterator} -lt ${number_of_iterations} ]; do
		TraceLogging "Current loop iteration is number ${loop_iterator} and contains ${source_files[${loop_iterator}]}"
		#If the object exists, continue, otherwise error to standard, remove the the element and proceed
		if [[ -e ${source_files[${loop_iterator}]} ]]; then
			DebugLogging "${source_files[${loop_iterator}]} exists!"
		else
			WarnLogging "${source_files[${loop_iterator}]} no longer exists! Removing from the list to transfer"
			DebugLogging "Before removal of entry, array looks like: ${source_files[@]}"
			DebugLogging "Loop iteration is ${loop_iterator}"
			#Remove this object from the index
			unset source_files[${loop_iterator}]
			#Reindex
			source_files=( "${source_files[@]}" )
			DebugLogging "After reindex, array looks like: ${source_files[@]}"
			#To ensure all elements are evaluated through the loop, decrement the loop_iterator and number_of_iterations
			let loop_iterator--
			let number_of_iterations--
		fi
		let loop_iterator++
	done

	#Check array after loop
	number_of_iterations=`echo ${#source_files[@]}`
	DebugLogging "After removal of missing files, number of iterations for loop is ${number_of_iterations}"

	#Unset items for portability
	unset loop_iterator
	unset number_of_iterations
fi
}

TestBatchDir () {
#############################################################################
### TestBatchDir - Purpose is to ensure temp batch dir is writable
#############################################################################
#Verify /tmp dir is writable
[ -w ${sftp_batchdir} ]
CaptureExitCode
VerifyExitCode "Unable to write to ${sftp_batchdir} directory"
#Get will run this first but the function will be called after that, if sftp_batch already exists, don't recreate
if [ ${sftp_batch} ]; then
	DebugLogging "SFTP batch variable already exists, continuing..."
else
	#If it exists and is writable, create the batch file
	sftp_batch=`mktemp ${sftp_batchdir}/sftp_batch$(date +_%Y-%m-%d_%H%M%S)_XXXXXXXXXX.dat`
	CaptureExitCode
	VerifyExitCode "Unable to create ${sftp_batch}"
	DebugLogging "sFTP Batch File is ${sftp_batch}" 
fi
}

TestBackupDir () {
#############################################################################
### TestPutBackupDir - Purpose is to ensure backup dir exists
#############################################################################
if [[ ${get_or_put} == 'put' ]]; then
	#Check if the sent directory exists, if not create it
	[ -d ${outbound_backupdir} ] || mkdir -p ${outbound_backupdir}
	CaptureExitCode
	VerifyExitCode "Could not verify or create ${source_path}/sent"
	DebugLogging "The outbound backup directory is set to ${outbound_backupdir}"
elif [[ ${get_or_put} == 'get' ]]; then
	#Check if the sent directory exists, if not create it
	[ -d ${inbound_backupdir} ] || mkdir -p ${inbound_backupdir}
	CaptureExitCode
	VerifyExitCode "Could not verify or create ${source_path}/received"
	DebugLogging "The inbound backup directory is set to ${inbound_backupdir}"
fi
}

TestSftpConnection () {
#############################################################################
### TestSftpConnection - Purpose is to ensure sftp connection works with pub
### 	key authentication
#############################################################################

#create test file
/bin/echo "exit">${sftp_batch}
#set permissions on file so d_ user can read it
/bin/chmod 777 ${sftp_batch}

#Call the sftp function to run the batch just created
CallSFTP ${sftp_ip} ${sftp_port} ${sftp_batch} ${sftp_user}
}

TestSftpDestDir () {
#############################################################################
### TestSftpDestDir - Purpose is to ensure destination directory exists
#############################################################################

#Only needed for put script
if [[ ${get_or_put} == 'put' ]]; then
	#Spool batch file to check if the directory exists
	/bin/echo "cd ${target_path}">${sftp_batch}
	CaptureExitCode
	VerifyExitCode "Could not create ${sftp_batch}"

	#Sftp using the batch file, check exit code from sftp and if directory doesn't exist, try to create it, if unable to create exit with error

	if [[ ${sftp_user} ]]; then
		#Attempt to sftp to server on required port
		DebugLogging "Custom user specified, attempting to login with user/pass"
		#If error is obtained, exit and attempt to create the directory
		if /usr/bin/sftp -b ${sftp_batch} -oPort=${sftp_port} ${sftp_user}@${sftp_ip} >>${log_instance_file} 2>&1; then
			DebugLogging "Successful check of directory ${target_path}, proceeding..."
		else
			DebugLogging "Attempting to create ${target_path} on sftp server..."
			echo "mkdir ${target_path}">${sftp_batch}
			RetryCommand "/usr/bin/sftp -b ${sftp_batch} -oPort=${sftp_port} ${sftp_ip}"
			VerifyExitCode "Could not create ${target_path} on sftp server"
			DebugLogging "Creation of ${target_path} on sftp server successful"
		fi
	else
		#Attempt to sftp to server on required port
		DebugLogging "No user specified, attempting to login with public key authentication"
		#If error is obtained, exit and attempt to create the directory
		if /usr/bin/sftp -b ${sftp_batch} -oPort=${sftp_port} ${sftp_ip}; then
			:
		else
			echo "mkdir ${target_path}">${sftp_batch}
			RetryCommand "/usr/bin/sftp -b ${sftp_batch} -oPort=${sftp_port} ${sftp_ip}"
			VerifyExitCode "Could not create ${target_path} on sftp server"
		fi
	fi
fi
}

PutTransferFile () {
#############################################################################
### PutTransferFile - Purpose is to build the batch for put transfer
#############################################################################

if [[ ${get_or_put} == 'put' ]]; then
	DebugLogging "Building the put batchfile for later sftp call"
	#Spool batch file
	/bin/echo "lcd ${source_path}
cd ${target_path}">${sftp_batch}


	#Depending on how many files are passed in, we need to create a put command for each
	for file in ${source_files[*]}; do
		#Test if file name has a . at the end, if so rename the file to drop the . due to sftp not able to transfer a file which ends in a period
		if [ ${file: -1} = "." ] ; then
			DebugLogging "Identified a file ${file} that has a trailing '.' - removing..."
			temp_file=`echo ${file}`
			file=`echo ${file} | sed 's/.$//'`
			mv ${temp_file} ${file}
			CaptureExitCode
			VerifyExitCode "Unable to move or rename ${temp_file} to ${file}"
			DebugLogging "File ${file} has successfully had trailing '.' removed"
		fi
		#Insert the put command for sftp to use
		/bin/echo "put \"${file}\"">>${sftp_batch}
		move_to_sent="${file} ${move_to_sent}"
	done
	
	#Place exit as final line in sftp batch to exit cleanly
	/bin/echo "exit">>${sftp_batch}
	CaptureExitCode
	VerifyExitCode "Could not create ${sftp_batch}"

	DebugLogging "Batch file built, attempting to run..."
	CallSFTP ${sftp_ip} ${sftp_port} ${sftp_batch} ${sftp_user}
	StandardLog "Batch file ran successfully and contained the following files: ${source_files[*]}"
fi

}

GetTransferFile () {
#############################################################################
### GetTransferFile - Purpose is to build the batch for get transfer
#############################################################################
#Only fire for get scripts
if [[ ${get_or_put} == 'get' ]]; then
	DebugLogging "Building the get batchfile for later sftp call"
	#Spool batch file
	/bin/echo "cd ${source_path}">${sftp_batch}

	#Depending on how many files are passed in, we need to create a get command for each
	for file in ${source_files[*]}; do
			/bin/echo "lcd ${target_path}">>${sftp_batch}
			/bin/echo "get ${file}">>${sftp_batch}
			/bin/echo "lcd ${inbound_backupdir}">>${sftp_batch}
			/bin/echo "get ${file}">>${sftp_batch}
			/bin/echo "rm ${file}">>${sftp_batch}
	done


	/bin/echo "exit">>${sftp_batch}
	CaptureExitCode
	VerifyExitCode "Could not create ${sftp_batch}"

	#Sftp using the batch file, check exit code from sftp and if directory doesn't exist, try to create it, if unable to create exit with error
	RetryCommand "/usr/bin/sftp -b ${sftp_batch} -oPort=${sftp_port} ${sftp_ip}"
	CaptureExitCode 
	VerifyExitCode "Unable to sftp files ${source_files[*]}"
	StandardLog "Batch file ran successfully and obtained the following files: ${source_files[*]}"
fi
}

MoveToSent () {
#############################################################################
### MoveToSent - Purpose is to backup the transferred file
#############################################################################
#Only fire for put scripts
if [[ ${get_or_put} == 'put' ]]; then
	#Backup sent file to the 'sent' subdir under the source directory location
	for file in ${move_to_sent}; do
			DebugLogging "Moving ${file} to ${outbound_backupdir}"
			#if the file exists in the 'sent' directory, another file name will be used, only works once
			/bin/mv -f "${file}" ${outbound_backupdir}
			CaptureExitCode
			VerifyExitCode "Unable to move ${source_path_and_file} to ${source_path}/sent/"
	done


	#Unset items for portability
	unset file
fi
}

CleanupBatch () {
#######################################
#Remove the batch file
#######################################
if [[ ${retain_batch_file} = 'n' ]]; then
	DebugLogging "User opted to remove the batch file in the conf file ${config_path}"
	RemoveFile ${sftp_batch}
else
	DebugLogging "User opted to retain the batch file in the conf file ${config_path}"
fi
}

CleanupInstanceLog () {
#######################################
#Remove the instance log
#######################################
if [[ ${retain_instance_log} = 'n' ]]; then
	DebugLogging "User opted to remove the debug log in the conf file ${config_path}"
	RemoveFile ${log_instance_file}
else
	DebugLogging "User opted to retain the debug log in the conf file ${config_path}"
fi
}

ExitSuccess () {
#######################################
#Exit with success
#######################################
DebugLogging "Ending script with success!"
#Exit successfully
exit 0
}

FailCheckExitClean () {
############################################################################
### ScriptFailCheck = Purpose is to check fail state and take appropriate action
############################################################################

if [ "${fail_state}" = "1" ]; then
	CleanupBatch
	EmailFile "${email_recipients}" "${log_instance_file}" "SFTP transfer on `hostname` has failed!"
	CleanupInstanceLog
	FatalLogging "Ending script!"
	exit 1
fi

}

###########################################################
### Main execution area
###########################################################
ImportConfig $*
ImportGlobalFunctions
LoggingDirSetupCustom
LoggingSetupCustom
WelcomeScreen $* 
ScriptChecks
ProcessInputSwitches $*
GetSourceFiles
PutAssignBackupDir
CheckGlobalVariables
RemoveDirectories
CheckSourceFiles
ReplaceSpecChar
InsertDate
TestSourceFile
TestBatchDir
TestBackupDir
TestSftpConnection
TestSftpDestDir
PutTransferFile
GetTransferFile
MoveToSent
CleanupBatch
CleanupInstanceLog
ExitSuccess