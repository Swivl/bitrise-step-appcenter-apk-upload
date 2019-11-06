#!/bin/bash

'app_project_version_name': ${app_project_version_name}
'app_project_version_code': ${app_project_version_code}
'app_apk_path': ${app_apk_path}
'app_mapping_path': ${app_mapping_path:-''}
'app_center_app_id': ${app_center_app_id}
'app_center_access_token': ${app_center_access_token}
'app_center_distribution_group': ${app_center_distribution_group}
'app_center_release_notes': ${app_center_release_notes:-''}

if [[ -n "${app_mapping_path}" ]]; then

    echo "Version name: "${app_project_version_name}
    echo "Version code: "${app_project_version_code}

	echo "mapping.txt is found."
	echo "run AppCenter mapping.txt uploader..."

	FILENAME="mapping.txt"
	cp ${app_mapping_path} ./${FILENAME}
	sudo apt install -y jq >/dev/null

	RESULT_JSON=`curl -X POST "https://api.appcenter.ms/v0.1/apps/${app_center_app_id}/symbol_uploads" \
	 -H "accept: application/json" \
	 -H "X-API-Token: ${app_center_access_token}" \
	 -H "Content-Type: application/json" \
	 -d "{ \"symbol_type\": \"AndroidProguard\", \"file_name\": \"${FILENAME}\", \"build\": \"${app_project_version_code}\", \"version\": \"${app_project_version_name}\"}"`

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

	curl -X PATCH "https://api.appcenter.ms/v0.1/apps/${app_center_app_id}/symbol_uploads/${SYMBOL_UPLOAD_ID}" \
	-H "accept: application/json" \
	-H "X-API-Token: ${app_center_access_token}" \
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

appcenter distribute release --token "${app_center_access_token}" --file "${app_apk_path}" --app "${app_center_app_id}" --group "${app_center_distribution_group}" --release-notes "${app_center_release_notes}"

exit 0
