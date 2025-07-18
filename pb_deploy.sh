#!/bin/bash
#
# Custom Deploy Script for PBRP
#
# Copyright (C) 2019 - 2020, Manjot Sidhu <manjot.techie@gmail.com>
# Rokib Hasan Sagar <rokibhasansagar2014@outlook.com>
# Mohd Faraz <mohd.faraz.abc@gmail.com>
# PitchBlack Recovery Project <pitchblackrecovery@gmail.com>
#
# This software is licensed under the terms of the GNU General Public
# License version 2, as published by the Free Software Foundation, and
# may be copied, distributed, and modified under those terms.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Please maintain this if you use this script or any part of it
#
# Required Arguments: BUILD_TYPE(OFFICIAL/BETA/TEST) VENDOE/OEM(such as xiaomi) CODENAME(such as rolex)

test $# -lt 3 && echo -e "Give Proper arguments\nRequired Arguments: BUILD_TYPE(OFFICIAL/BETA/TEST) VENDOE/OEM(such as xiaomi) CODENAME(such as rolex)" && exit 1;
DEPLOY_TYPE=$1
VENDOR=$2
CODENAME=$3
blue='\033[0;34m'
cyan='\033[0;36m'
green='\e[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'
purple='\e[0;35m'
white='\e[0;37m'
if [ ! -d "$(pwd)/out/target/product/${CODENAME}/" ]; then
	echo -e "${red}Plz Run in the Root of the compilation enviromnent\n${nocol}"
	exit 1;
fi
curl https://raw.githubusercontent.com/PitchBlackRecoveryProject/vendor_utils/pb/pb_devices.json > /tmp/pb_devices.json
maintainer=$(python3 vendor/utils/pb_devices.py verify $VENDOR $CODENAME true)

# GitHub Username & Repository Name
GH_USER=PitchBlackRecoveryProject
GH_REPO=android_device_${VENDOR}_${CODENAME}-pbrp
GH_SHA=$(cd $(pwd)/device/${VENDOR}/${CODENAME} && git rev-list --branches | head -1)

if [ -z ${GH_BOT_TOKEN} ] || [ -z ${BOT_API} ]; then
	echo "Make sure all ENV variables (GH_BOT_TOKEN/BOT_API) are available"
	exit -1;
fi

UPLOAD_PATH=$(pwd)/out/target/product/${CODENAME}/upload/

# Version
TWRP_V=$(cat $(pwd)/bootable/recovery/variables.h | egrep "define\s+TW_MAIN_VERSION_STR" | awk '{print $3}' | tr -d '"')
VERSION=$(cat $(pwd)/bootable/recovery/variables.h | egrep "define\s+PB_MAIN_VERSION" | awk '{print $3}' | tr -d '"')

pb_sticker="https://thumbs.gfycat.com/NauticalMellowAlpineroadguidetigerbeetle-mobile.mp4"

# Validate and Prepare for deploy
if [[ "$DEPLOY_TYPE" == "OFFICIAL" ]]; then
	# Official Deploy = SF + GHR + WP + TG (Main Channel)

	DEPLOY_TYPE_NAME="Official"
	RELEASE_TAG=${VERSION}
	BUILDFILE=$(find $(pwd)/out/target/product/${CODENAME}/PBRP*-OFFICIAL.zip 2>/dev/null)

elif [[ "$DEPLOY_TYPE" == "BETA" ]]; then
	# Beta Deploy = SF + GHR + WP + TG (Beta Group)

	DEPLOY_TYPE_NAME="Beta"
	RELEASE_TAG=${VERSION}-beta
	BUILDFILE=$(find $(pwd)/out/target/product/${CODENAME}/PBRP*-BETA.zip 2>/dev/null)

elif [[ "$DEPLOY_TYPE" == "TEST" ]]; then
	# Test Deploy = GHR + TG (Device Maintainers Chat)

	DEPLOY_TYPE_NAME="Test"
	RELEASE_TAG=${VERSION}-test
	BUILDFILE=$(find $(pwd)/out/target/product/${CODENAME}/PBRP*-UNOFFICIAL.zip 2>/dev/null)

else
	echo -e "Wrong Build Type Given, Required Build Type: OFFICIAL/BETA/TEST" && exit 1
fi

function get_device_name () {
	local DEVICE=$(cat /tmp/pb_devices.json | grep $1 -A 3 | grep name | awk -F[\"] '{print $4}')
	echo "$DEVICE"
}

function get_vendor () {
	echo "$(echo ${1} | cut -d' ' -f1)"
}
# Common Props
BUILD_IMG=""
for img in recovery.img boot.img vendor_boot.img; do
    BUILD_IMG=$(find "$(pwd)/out/target/product/${CODENAME}" -type f -name "$img" 2>/dev/null | head -n 1)
    [ -n "$BUILD_IMG" ] && break
done

if [ -z "$BUILDFILE" ]; then
    BUILDFILE="$BUILD_IMG"
    export TZ="Asia/Kolkata"
    BUILD_DATE=$(date +%Y%m%d)
    BUILD_DATETIME=$(date +%Y%m%d-%H%M)
else
    BUILD_DATE=$(echo "$BUILDFILE" | awk -F'[-]' '{print $4}')
    BUILD_DATETIME="$(echo "$BUILDFILE" | awk -F'[-]' '{print $4}')-$(echo "$BUILDFILE" | awk -F'[-]' '{print $5}')"
fi
MD5=$(md5sum $BUILDFILE | awk '{print $1}')
FILE_SIZE=$( du -h $BUILDFILE | awk '{print $1}' )
TARGET_DEVICE=$(cat /tmp/pb_devices.json | grep ${CODENAME} -A 3 | grep name | awk -F[\"] '{print $4}')
BUILD_NAME=$(echo ${BUILDFILE} | awk -F['/'] '{print $NF}')
DEVICES=$(cat /tmp/pb_devices.json | grep ${CODENAME} -A 3 | grep unified | awk -F[\"] '{ for (i=4; i<NF; i=i+2) print $i }')

# Release Links
gh_link="https://github.com/${GH_USER}/${GH_REPO}/releases/download/${RELEASE_TAG}/${BUILD_NAME}"
sf_link="https://sourceforge.net/projects/pbrp/files/${CODENAME}/$(echo $BUILDFILE | awk -F'[/]' '{print $NF}')/download"
wp_link="https://pitchblackrecovery.com/${CODENAME}"
gp_link="https://pitchblackrecoverydevices.github.io/${CODENAME}/"

# Format for TG
FORMAT="PitchBlack Recovery for <b>$TARGET_DEVICE</b> (<code>${CODENAME}</code>)\n\n<b>Info</b>\n\nPitchBlack V${VERSION} <b>${DEPLOY_TYPE_NAME}</b>\nBased on TWRP ${TWRP_V}\n<b>Build Date</b>: <code>${BUILD_DATE:0:4}/${BUILD_DATE:4:2}/${BUILD_DATE:6}</code>\n\n<b>Maintainer</b>: ${maintainer}\n"
if [[ ! -z $CHANGELOG ]]; then
	FORMAT=${FORMAT}"\n<b>Changelog</b>:\n"${CHANGELOG}"\n"
fi
FORMAT=${FORMAT}"\n<b>MD5</b>: <code>$MD5</code>\n"
BUTTONS=
#Special format for unifieds
if [ ! -z "$DEVICES" ]; then
	UNIFORMAT="PitchBlack Recovery for <b>$(get_vendor $(get_device_name $(echo $DEVICES | cut -d' ' -f1)))</b>"
	TAGS=
	for i in $DEVICES; do
		TARGET_DEVICE=$(cat /tmp/pb_devices.json | grep -i ${i}  -A 1 | grep name | awk -F[\"] '{print $4}' | cut -d' ' -f2-)
		UNIFORMAT="${UNIFORMAT} <b>$TARGET_DEVICE</b> /"
		TAGS="${TAGS}#${i}    "
		wp_link="https://pitchblackrecovery.com/$(echo $i | sed "s:_:-:g")"
		BUTTONS="${BUTTONS}$i|$wp_link!"
	done
	UNIFORMAT="${UNIFORMAT:0:-1} (<code>${CODENAME}</code>)\n\n<b>Info</b>\n\nPitchBlack V${VERSION} <b>${DEPLOY_TYPE_NAME}</b>\nBased on TWRP ${TWRP_V}\n<b>Build Date</b>: <code>${BUILD_DATE:0:4}/${BUILD_DATE:4:2}/${BUILD_DATE:6}</code>\n\n<b>Maintainer</b>: ${maintainer}\n"
	if [[ ! -z $CHANGELOG ]]; then
		UNIFORMAT=${UNIFORMAT}"\n<b>Changelog</b>:\n"${CHANGELOG}"\n"
	fi
	UNIFORMAT=${UNIFORMAT}"\n<b>MD5</b>: <code>$MD5</code>\n\n${TAGS}\n"
	FORMAT=$UNIFORMAT
fi

# Deploy on SourceForge
function sf_deploy() {
	echo -e "${green}Deploying on SourceForge!\n${nocol}"

	# Install sshpass if not installed
	chksspb=$(which sshpass 2>/dev/null)
	if [[ "$chksspb" != "/usr/bin/sshpass" ]]; then
	    echo
	    printf "Sshpass is required but not installed!\n\nInstalling sspass...\n"
	    echo
	    ID_LIKE="$(cut -d'=' -f2 <<<$(grep ID_LIKE= /etc/os-release))"
	    echo
	        if [ "$ID_LIKE" == "arch" ]; then
	            sudo pacman -S sshpass --noconfirm
	        elif [ "$ID_LIKE" = "debian" ]; then
	            sudo apt-get install sshpass -y
	        fi
	else true;
	fi

	echo

	# SF Details
	echo
	echo "Build detected for :" $CODENAME
	echo "PitchBlack version :" $pbv
	echo "Build Date         :" $BUILD_DATE
	echo "Build Location     :" $BUILDFILE
	echo "MD5                :" $MD5
	echo

	if [ -z $SFUserName ]; then
		echo -e "${green}Enter SF Username${nocol}"
		read SFUserName
	fi
	if [ -z $SFPassword ]; then
		echo -e "${green}Enter SF Password${nocol}"
		read -s SFPassword
	fi
	cd $(pwd)/vendor/utils;

	# Check for Official
	python3 pb_devices.py verify "$VENDOR" "$CODENAME"
	if [[ "$?" == "0" ]]; then
		sshpass -p "${SFPassword}" rsync -avP --progress -e 'ssh -o StrictHostKeyChecking=no' ${BUILDFILE} "${SFUserName}"@web.sourceforge.net:/home/frs/project/pbrp/${CODENAME}/${BUILD_NAME}
		if [ "$?" != "0" ]; then
			sshpass -p "${SFPassword}" sftp ${SFUserName}@web.sourceforge.net <<-EOF
			cd /home/frs/project/pbrp/
			mkdir ${CODENAME}
			exit
			EOF
			sshpass -p "${SFPassword}" rsync -avP --progress -e 'ssh -o StrictHostKeyChecking=no' ${BUILDFILE} "${SFUserName}"@web.sourceforge.net:/home/frs/project/pbrp/${CODENAME}/${BUILD_NAME}
		fi
		if [ "$?" == "0" ]
		then
			echo -e "${green} Deployed On SOURCEFORGE SUCCESSFULLY\n${nocol}"
			cd ../../
			return 0
		else
			echo -e "${red} FAILED TO UPLOAD TO SOURCEFORGE\n${nocol}"
			cd ../../
			return 1
		fi
	else
		echo -e "${red} Device is not Official\n${nocol}"
		cd ../../
		return 2
	fi
}

# Function to create Samsung Odin TAR from images
function create_samsung_tar() {
    local OUT_DIR="$(pwd)/out/target/product/${CODENAME}"
    local TAR_NAME="PBRP-${CODENAME}-${VERSION}-${BUILD_DATETIME}-${DEPLOY_TYPE}-ODIN.tar"
    local TAR_PATH="${OUT_DIR}/${TAR_NAME}"
    
    echo -e "${cyan}Creating Samsung Odin TAR package...${nocol}"
    
    # Array to store found images
    local SAMSUNG_IMAGES=()
    
    # Check for images (including .img and .img.lz4 variants)
    for partition in recovery boot vendor_boot; do
        for ext in img img.lz4; do
            if [[ -f "${OUT_DIR}/${partition}.${ext}" ]]; then
                SAMSUNG_IMAGES+=("${partition}.${ext}")
                echo -e "${green}Found ${partition}.${ext} for TAR${nocol}"
                break  # Only use one version per partition
            fi
        done
    done

    if [[ ${#SAMSUNG_IMAGES[@]} -gt 0 ]]; then
        # Change to output directory to avoid full paths in TAR
        pushd "${OUT_DIR}" > /dev/null
        
        # Create TAR file with found images using ustar format (Samsung Odin requirement)
        echo -e "${cyan}Creating TAR: ${TAR_NAME}${nocol}"
        if ! tar -H ustar -cvf "${TAR_NAME}" "${SAMSUNG_IMAGES[@]}"; then
            echo -e "${red}Failed to create Samsung Odin TAR${nocol}"
            popd > /dev/null
            return 1
        fi
        
        # Create MD5 checksum and append to TAR file (Samsung Odin format)
        echo -e "${cyan}Adding MD5 checksum to TAR...${nocol}"
        if ! md5sum -t "${TAR_NAME}" >> "${TAR_NAME}"; then
            echo -e "${red}Failed to append MD5 checksum to TAR${nocol}"
            popd > /dev/null
            return 1
        fi
        
        # Rename TAR file to .tar.md5 (Samsung Odin format)
        if ! mv "${TAR_NAME}" "${TAR_NAME}.md5"; then
            echo -e "${red}Failed to rename TAR to .md5 format${nocol}"
            popd > /dev/null
            return 1
        fi
        
        echo -e "${green}Samsung Odin TAR created successfully: ${TAR_PATH}.md5${nocol}"
        echo -e "${green}TAR size: $(du -h "${TAR_NAME}.md5" | awk '{print $1}')${nocol}"
        
        # Return to original directory
        popd > /dev/null
        return 0
    else
        echo -e "${yellow}No Samsung images found for TAR creation${nocol}"
        return 1
    fi
}

# Deploy on GitHub Releases
function gh_deploy() {

	# Prepare Upload directory for Github Releases
	mkdir ${UPLOAD_PATH}

	# Copy Required Files
	if [[ ! -z ${BUILDFILE} ]]; then
	    cp $BUILDFILE $UPLOAD_PATH
	fi
	cp $BUILD_IMG $UPLOAD_PATH

	# Samsung TAR MD5 handling
	if [[ "${VENDOR}" == "samsung" ]]; then
    	# Find any existing TAR files (case insensitive, newest first)
    	BUILD_FILE_TAR=$(find $(pwd)/out/target/product/${CODENAME} -maxdepth 1 -type f -iname "*.tar.md5" -printf "%T@ %p\n" 2>/dev/null | 
                    	sort -nr | cut -d' ' -f2- | head -n 1)
    	
    	if [[ -z "${BUILD_FILE_TAR}" ]]; then
        	echo -e "${yellow}No existing TAR MD5 file found for Samsung device, creating one...${nocol}"
        	if create_samsung_tar; then
            	# Get the newly created TAR MD5 file
            	BUILD_FILE_TAR=$(find $(pwd)/out/target/product/${CODENAME} -maxdepth 1 -type f -iname "*.tar.md5" 2>/dev/null | head -n 1)
            	if [[ -n "${BUILD_FILE_TAR}" ]]; then
                	echo -e "${green}Successfully created Samsung Odin TAR MD5: ${BUILD_FILE_TAR}${nocol}"
            	else
                	echo -e "${red}Failed to locate newly created TAR MD5 file${nocol}"
                	exit 1
            	fi
        	else
            	echo -e "${red}Failed to create Samsung Odin TAR MD5${nocol}"
            	exit 1
        	fi
    	else
        	echo -e "${green}Using existing Samsung Odin TAR MD5: ${BUILD_FILE_TAR}${nocol}"
    	fi
    	
    	# Copy TAR MD5 to upload directory
    	if ! cp -v "${BUILD_FILE_TAR}" "${UPLOAD_PATH}/"; then
        	echo -e "${red}Failed to copy TAR MD5 file to upload directory${nocol}"
        	exit 1
    	fi

    	fi


	# Final Release
	ghr -t ${GH_BOT_TOKEN} -u ${GH_USER} -r ${GH_REPO} -n "$(echo $DEPLOY_TYPE_NAME) Release for $(echo $CODENAME)" -b "PBRP $(echo $RELEASE_TAG)" -c ${GH_SHA} -delete ${RELEASE_TAG} ${UPLOAD_PATH}

	return "$?"
}


# Deploy Official Build on Official Telegram Channel
function tg_official_deploy() {
	echo -e "${green}Deploying to Telegram!\n${nocol}"

	if [ -z "$DEVICES" ]; then
		python3 vendor/utils/scripts/telegram.py -c @pitchblackrecovery -AN "$pb_sticker" -C "$FORMAT" -D "Download|${wp_link}!Download - Mirror |${gp_link}!Chat|https://t.me/pbrpcom!Channel|https://t.me/pitchblackrecovery" -m "HTML"
	else
		python3 vendor/utils/scripts/telegram.py -c @pitchblackrecovery -AN "$pb_sticker" -C "$FORMAT" -D "${BUTTONS}Chat|https://t.me/pbrpcom!Channel|https://t.me/pitchblackrecovery" -m "HTML"
	fi

	echo -e "${green}Deployed to Telegram SUCCESSFULLY!\n${nocol}"
	return 0
}


# Deploy Beta Build on Official PBRP Testing Group
function tg_beta_deploy() {
	echo -e "${green}Deploying to Telegram!\n${nocol}"

	if [ -z "$DEVICES" ]; then
		python3 vendor/utils/scripts/telegram.py -c "-1001270222037" -AN "$pb_sticker" -C "$FORMAT" -D "Download|$wp_link!Download - Mirror |${gp_link}!Beta Chat|https://t.me/pbrp_testers!Channel|https://t.me/joinchat/AAAAAEu2DNXX-P7RgFWBcw" -m "HTML"
	else
		python3 vendor/utils/scripts/telegram.py -c "-1001270222037" -AN "$pb_sticker" -C "$FORMAT" -D "${BUTTONS}Beta Chat|https://t.me/pbrp_testers!Channel|https://t.me/joinchat/AAAAAEu2DNXX-P7RgFWBcw" -m "HTML"
	fi


	echo -e "${green}Deployed to Telegram SUCCESSFULLY!\n${nocol}"
	return 0
}

# Deploy Test Build on Official PBRP Device Maintainers Group
function tg_test_deploy() {
	echo -e "${green}Deploying to Telegram Device Maintainers Chat!\n${nocol}"

    TEST_LINK="https://github.com/${GH_USER}/${GH_REPO}/releases/download/${RELEASE_TAG}/$(echo $BUILDFILE | awk -F'[/]' '{print $NF}')"

    MAINTAINER_MSG="PitchBlack Recovery for \`${VENDOR}\` \`${CODENAME}\` is available Only For Testing Purpose\n\n"
    if [[ ! -z $MAINTAINER ]]; then MAINTAINER_MSG=${MAINTAINER_MSG}"Maintainer: ${MAINTAINER}\n\n"; fi
    if [[ ! -z $CHANGELOG ]]; then MAINTAINER_MSG=${MAINTAINER_MSG}"Changelog:\n"${CHANGELOG}"\n\n"; fi

    MAINTAINER_MSG=${MAINTAINER_MSG}"Go to ${TEST_LINK} to download it."
    if [[ $USE_SECRET_BOOTABLE == 'true' ]]; then
        python3 vendor/utils/scripts/telegram.py -c "-1001465331122" -M "$MAINTAINER_MSG" -m "HTML"
    else
        python3 vendor/utils/scripts/telegram.py -c "-1001228903553" -M "$MAINTAINER_MSG" -m "HTML"
    fi

    echo -e "${green}Deployed to Telegram SUCCESSFULLY!\n${nocol}"
    return 0
}

# Deploy on PBRP Database for WP
# NOTE: Must be called after sf_deploy
function wp_deploy() {
	echo -e "${green}Deploying to PBRP Database!\n${nocol}"

	curl -i -X POST 'https://us-central1-pbrp-prod.cloudfunctions.net/release' -H "Authorization: Bearer ${GCF_AUTH_KEY}" -H "Content-Type: application/json" --data "{\"codename\": \"$CODENAME\", \"vendor\":\"$VENDOR\", \"md5\": \"$MD5\", \"size\": \"$FILE_SIZE\", \"sf_link\": \"$sf_link\", \"gh_link\": \"$gh_link\",\"version\": \"$VERSION\", \"build_type\": \"$DEPLOY_TYPE\"}"

	echo -e "${green}Deployed to PBRP Database SUCCESSFULLY!\n${nocol}"
	return 0
}

if [[ "$DEPLOY_TYPE" == "OFFICIAL" ]]; then
	zipcounter=$(find $(pwd)/out/target/product/$CODENAME/PBRP*-OFFICIAL.zip 2>/dev/null | wc -l)
elif [[ "$DEPLOY_TYPE" == "BETA" ]]; then
	zipcounter=$(find $(pwd)/out/target/product/$CODENAME/PBRP*-BETA.zip 2>/dev/null | wc -l)
else
	zipcounter=$(find $(pwd)/out/target/product/$CODENAME/PBRP*-UNOFFICIAL.zip 2>/dev/null | wc -l)
fi

	recoveryimgcheck=$(find "$(pwd)/out/target/product/$CODENAME" -type f -name "recovery.img" -o -name "boot.img" -o -name "vendor_boot.img" 2>/dev/null | wc -l)
 
if [[ "$recoveryimgcheck" > "0" ]]; then
	if [[ "$zipcounter" > "1" ]]; then
		printf "${red}More than one zips dected! Remove old build...\n${nocol}"
	else
		# Time for Deployment!
		if [[ "$DEPLOY_TYPE" == "OFFICIAL" ]]; then
			# Official Deploy = SF + GHR + WP + TG (Main Channel)

			if ! sf_deploy; then echo -e "Error in SourceForge Deployment." && exit 1; fi
			if ! gh_deploy; then echo -e "Error in GitHub Releases Deployment." && exit 1; fi
			if ! wp_deploy; then echo -e "Error in PBRP Website Deployment." && exit 1; fi
			if ! tg_official_deploy; then  echo -e "Error in Telegram Official Deployment." && exit 1; fi
			wget https://raw.githubusercontent.com/PitchBlackRecoveryProject/PitchBlackRecoveryProject.github.io/refs/heads/pb/assets/scripts/update_builds_json.sh
			bash update_builds_json.sh "$VENDOR" "$CODENAME" "$VERSION" "$DEPLOY_TYPE" "${sf_link}" "$CHANGELOG"
		elif [[ "$DEPLOY_TYPE" == "BETA" ]]; then
			# Beta Deploy = SF + GHR + WP + TG (Beta Group)

			if ! sf_deploy; then echo -e "Error in SourceForge Deployment." && exit 1; fi
			if ! gh_deploy; then echo -e "Error in GitHub Releases Deployment." && exit 1; fi
			if ! wp_deploy; then echo -e "Error in PBRP Website Deployment." && exit 1; fi
			if ! tg_beta_deploy; then  echo -e "Error in Telegram Beta Deployment." && exit 1; fi
			wget https://raw.githubusercontent.com/PitchBlackRecoveryProject/PitchBlackRecoveryProject.github.io/refs/heads/pb/assets/scripts/update_builds_json.sh
   			bash update_builds_json.sh "$VENDOR" "$CODENAME" "$VERSION" "$DEPLOY_TYPE" "${sf_link}" "$CHANGELOG"
		elif [[ "$DEPLOY_TYPE" == "TEST" ]]; then
			# Test Deploy = GHR + TG (Device Maintainers Chat)

			if ! gh_deploy; then  echo -e "Error in GitHub Releases Deployment." && exit 1; fi
			if ! tg_test_deploy; then  echo -e "Error in Telegram Test Deployment." && exit 1; fi
		else
			echo -e "Wrong Arguments Given, Required Arguments: BUILD_TYPE(OFFICIAL/BETA/TEST)" && exit 1
		fi
	fi
else
	echo
	printf "${red}No build found\n${nocol}"
	echo
fi
