#!/bin/bash

envman add --key APP_PROJECT_NAME
envman add --key APP_CENTER_APP_ID
envman add --key APP_CENTER_ACCESS_TOKEN
envman add --key APP_CENTER_DISTRIBUTION_GROUP
envman add --key APP_CENTER_RELEASE_NOTE

echo "run AppCenter mapping.txt uploader..."

VERSION_NAME=`grep "versionName" ${BITRISE_SOURCE_DIR}/${APP_PROJECT_NAME}/build.gradle | sed -e 's/[^.0-9]//g'`
VERSION_CODE=`grep "versionCode" ${BITRISE_SOURCE_DIR}/${APP_PROJECT_NAME}/build.gradle | sed -e 's/[^.0-9]//g'`

echo "Version name: "$VERSION_NAME
echo "Version code: "$VERSION_CODE

if [ -n "${BITRISE_MAPPING_PATH}" ]; then
	echo "mapping.txt is found."
	echo "run AppCenter mapping.txt uploader..."

	FILENAME="mapping_"$(date +%Y%m%d_%H%M%S)"_GMT.txt"
	cp ${BITRISE_MAPPING_PATH} ./${FILENAME}
	sudo apt install -y jq >/dev/null

	RESULT_JSON=`curl -X POST "https://api.appcenter.ms/v0.1/apps/${APP_CENTER_APP_ID}/symbol_uploads" \
	 -H "accept: application/json" \
	 -H "X-API-Token: ${APP_CENTER_ACCESS_TOKEN}" \
	 -H "Content-Type: application/json" \
	 -d "{ \"symbol_type\": \"AndroidProguard\", \"file_name\": \"${FILENAME}\", \"build\": \"${VERSION_CODE}\", \"version\": \"${VERSION_NAME}\"}"`

	SYMBOL_UPLOAD_ID=`echo ${RESULT_JSON} | jq '.symbol_upload_id' -r`
	UPLOAD_URL=`echo ${RESULT_JSON} | jq '.upload_url' -r`

	curl -v -X PUT ${UPLOAD_URL} \
	 -H "Content-Type: application/octet-stream" \
	 -H "Postman-Token: ${API-TOKEN}" \
	 -H "User-Agent: PostmanRuntime/7.6.1" \
	 -H "Accept: */*" -H "cache-control: no-cache" \
	 -H 'x-ms-blob-type: BlockBlob' \
	 -H "x-ms-date: ${DATE_NOW}" \
	 --data-binary "@${FILENAME}"

	curl -X PATCH "https://api.appcenter.ms/v0.1/apps/${APP_CENTER_APP_ID}/symbol_uploads/${SYMBOL_UPLOAD_ID}" \
	-H "accept: application/json" \
	-H "X-API-Token: ${APP_CENTER_ACCESS_TOKEN}" \
	-H "Content-Type: application/json" \
	-d "{ \"status\": \"committed\"}"

else
  echo "mapping.txt not found."
  echo "skip mapping.txt upload step."
fi

echo "run AppCenter apk uploader..."

if hash appcenter 2>/dev/null; then
  echo "Microsoft AppCenter CLI already installed."
else
  echo "Microsoft AppCenter CLI is not installed. Installing..."
  npm install -g appcenter-cli
fi

if [ -n "${BITRISE_MAPPING_PATH}" ]; then
  echo "use signed apk"
  APP_CENTER_APK_PATH=$BITRISE_SIGNED_APK_PATH
else
  echo "use unsign apk"
  APP_CENTER_APK_PATH=$BITRISE_APK_PATH
fi

appcenter distribute release -f "${APP_CENTER_APK_PATH}" -r "${APP_CENTER_RELEASE_NOTE}" -a "${APP_CENTER_APP_ID}" --token "${APP_CENTER_ACCESS_TOKEN}" -g "${APP_CENTER_DISTRIBUTION_GROUP}"

exit 0
