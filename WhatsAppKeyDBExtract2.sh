#!/usr/bin/env bash

tput bold;
tput setaf 2;
# https://martin-thoma.com/colorize-your-scripts-output/
# https://unix.stackexchange.com/questions/269077/tput-setaf-color-table-how-to-determine-color-codes
textNormal=$(tput setaf 2)
textReset=$(tput sgr0)
textError=$(tput setaf 1)

is_adb=1
[[ -z $(which adb) ]] && { is_adb=0; }
is_curl=1
[[ -z $(which curl) ]] && { is_curl=0; }
is_grep=1
[[ -z $(which grep) ]] && { is_grep=0; }
is_java=1
[[ -z $(which java) ]] && { is_java=0; }
is_tar=1
[[ -z $(which tar) ]] && { is_tar=0; }
is_tr=1
[[ -z $(which tr) ]] && { is_tr=0; }

echo "
=========================================================================
= This script will extract the WhatsApp Key file and DB on Android 4.0+ =
= You DO NOT need root for this to work but you DO need Java installed. =
= If your WhatsApp version is greater than 2.11.431 (most likely), then =
= a legacy version will be installed temporarily in order to get backup =
= permissions. You will NOT lose ANY data and your current version will =
= be restored at the end of the extraction process so try not to panic. =
= Script by: TripCode (Greets to all who visit: XDA Developers Forums). =
= Thanks to: dragomerlin for ABE and to Abinash Bishoyi for being cool. =
=         ###          Version: v4.7 (12/10/2016)          ###          =
=========================================================================
"
if (($is_adb == 0)); then
	echo "${textError} Error: adb is not installed - please install adb and run again! ${textReset}"
elif (($is_curl == 0)); then
	echo "${textError} Error: curl is not installed - please install curl and run again!${textReset}"
elif (($is_grep == 0)); then
	echo "${textError} Error: grep is not installed - please install grep and run again!${textReset}"
elif (($is_java == 0)); then
	echo "${textError} Error: java is not installed - please install java and run again!${textReset}"
elif (($is_tar == 0)); then
	echo "${textError} Error: tar is not installed - please install tar and run again!${textReset}"
elif (($is_tr == 0)); then
	echo "${textError} Error: tr is not installed - please install tr and run again!${textReset}"
else
	echo "\nPlease connect your Android device with USB Debugging enabled:\n"
	adb kill-server
	adb start-server
	adb wait-for-device
	sdkver=$(adb shell getprop ro.build.version.sdk | tr -d '[[:space:]]')
	echo "[DEBUG] sdkver: ${sdkver}"
	sdpath=$(adb shell "echo \$EXTERNAL_STORAGE/WhatsApp/Databases/.nomedia" | tr -d '[[:space:]]')
	echo "[DEBUG] sdpath: ${sdpath}"
	if [ $sdkver -le 13 ]; then
		echo "\nUnsupported Android Version - this method only works on 4.0 or higher :/\n"
		adb kill-server
	else
		apkpath=$(adb shell pm path com.whatsapp | grep package | tr -d '[[:space:]]')
		echo "[DEBUG] apkpath: ${apkpath}"
		version=$(adb shell dumpsys package com.whatsapp | grep versionName | tr -d '[[:space:]]')
		echo "[DEBUG] version: ${version}"
		apkflen=$(curl -sI http://www.cdn.whatsapp.net/android/2.11.431/WhatsApp.apk | grep Content-Length | grep -o '[0-9]' | tr -d '[[:space:]]')
		echo "[DEBUG] apkflen: ${apkflen}"
		if [ $apkflen -eq 18329558 ]; then
			apkfurl=http://www.cdn.whatsapp.net/android/2.11.431/WhatsApp.apk
		else
			apkfurl=http://whatcrypt.com/WhatsApp-2.11.431.apk
		fi
		echo "[DEBUG] apkfurl: ${apkfurl}"
		if [ ! -f tmp/LegacyWhatsApp.apk ]; then
			echo "\nDownloading legacy WhatsApp 2.11.431 to local folder\n"
			curl -o tmp/LegacyWhatsApp.apk $apkfurl
			echo ""
		else
			echo "\nFound legacy WhatsApp 2.11.431 in local folder\n"
		fi
		if [ -z "$apkpath" ]; then
			echo "\nWhatsApp is not installed on the target device\nExiting ..."
		else
			apkname=$(basename ${apkpath/package:/})
			echo "[DEBUG] apkname: ${apkname}"
			echo "WhatsApp ${version/versionName=/} installed\n"
			if [ $sdkver -ge 11 ]; then
				adb shell am force-stop com.whatsapp
			else
				adb shell am kill com.whatsapp
			fi
			echo "Backing up WhatsApp ${version/versionName=/}"
			adb pull ${apkpath/package:/} tmp
			echo "Backup complete\n"
			if [ $sdkver -ge 23 ]; then
				echo "Removing WhatsApp ${version/versionName=/} skipping data"
				adb shell pm uninstall -k com.whatsapp
				echo "Removal complete\n"
			fi
			echo "Installing legacy WhatsApp 2.11.431..."
			if [ $sdkver -ge 17 ]; then
				adb install -r -d tmp/LegacyWhatsApp.apk
			else
				adb install -r tmp/LegacyWhatsApp.apk
			fi
			# https://askubuntu.com/questions/29370/how-to-check-if-a-command-succeeded
			retval=$?
			if [ $retval -ne 0 ]; then
				echo "... FAILED! ErrorCode: $retval"
				echo "\nRestoring WhatsApp ${version/versionName=/}"
				if [ $sdkver -ge 17 ]; then
					adb install -r -d tmp/$apkname
				else
					adb install -r tmp/$apkname
				fi
				if [ $? -eq 0 ]; then
					echo "Restore FAILED! ErrorCode: $?"
				else
					echo "Restore complete\n\nCleaning up temporary files ..."
				fi
				read -p "Please press Enter to quit..."
				tput sgr0
				exit
			fi
			echo "... Install complete\n"
			if [ $sdkver -ge 23 ]; then
				adb backup -f tmp/whatsapp.ab com.whatsapp
			else
				adb backup -f tmp/whatsapp.ab -noapk com.whatsapp
			fi
			if [ $? -ne 0 ]; then
				echo "adb backup FAILED! ErroCode: $?"
				exit
			fi
			if [ -f tmp/whatsapp.ab ]; then
				echo "\nPlease enter your backup password (leave blank for none) and press Enter: "
				read password
				java -jar bin/abe.jar unpack tmp/whatsapp.ab tmp/whatsapp.tar $password
				if [ $? -ne 0 ]; then
					echo "java execution error! ErroCode: $?"
					exit
				fi
				tar xvf tmp/whatsapp.tar -C tmp apps/com.whatsapp/f/key
				if [ $? -eq 0 ]; then
					echo "\nSaving whatsapp.cryptkey ..."
					cp tmp/apps/com.whatsapp/f/key extracted/whatsapp.cryptkey
					echo "\nPushing cipher key to: $sdpath"
					adb push tmp/apps/com.whatsapp/f/key $sdpath
					tar xvf tmp/whatsapp.tar -C tmp apps/com.whatsapp/db/msgstore.db
					if [ $? -eq 0 ]; then
						echo "Saving msgstore.db ..."
						cp tmp/apps/com.whatsapp/db/msgstore.db extracted/msgstore.db
						tar xvf tmp/whatsapp.tar -C tmp apps/com.whatsapp/db/wa.db
						if [ $? -eq 0 ]; then
							echo "Saving wa.db ..."
							cp tmp/apps/com.whatsapp/db/wa.db extracted/wa.db
							tar xvf tmp/whatsapp.tar -C tmp apps/com.whatsapp/db/axolotl.db
							if [ $? -eq 0 ]; then
								echo "Saving axolotl.db ..."
								cp tmp/apps/com.whatsapp/db/axolotl.db extracted/axolotl.db
								tar xvf tmp/whatsapp.tar -C tmp apps/com.whatsapp/db/chatsettings.db
								if [ $? -eq 0 ]; then
									echo "Saving chatsettings.db ..."
									cp tmp/apps/com.whatsapp/db/chatsettings.db extracted/chatsettings.db
								fi				
							fi				
						fi				
					fi				
				fi
			else
				echo "Operation failed"
			fi
			if [ ! -f tmp/$apkname ]; then
				echo "\nDownloading WhatsApp ${version/versionName=/} to local folder\n"
				curl -o tmp/$apkname http://www.cdn.whatsapp.net/android/${version/versionName=/}/WhatsApp.apk
			fi
			echo "\nRestoring WhatsApp ${version/versionName=/}"
			if [ $sdkver -ge 17 ]; then
				adb install -r -d tmp/$apkname
			else
				adb install -r tmp/$apkname
			fi
			retval=$?
			if [ $retval -eq 0 ]; then
				echo "Restore complete\n\nCleaning up temporary files ..."
			else
				echo "Restore FAILED! ErrorCode: $retval"
			fi
			rm tmp/whatsapp.ab
			rm tmp/whatsapp.tar
			rm -rf tmp/apps
			rm tmp/$apkname
			echo "Done\n\nOperation complete\n"
		fi
	fi
	adb kill-server
fi
read -p "Please press Enter to quit..."
tput sgr0
exit 0
