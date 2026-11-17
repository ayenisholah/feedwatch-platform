#!/usr/bin/env bash
# Creates an access key for the IAM user feedwatch-deployer and stores it as the GitHub Actions
# secrets AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in all four Feedwatch repos (ADR 0008).
#
# Run by the owner, with AWS credentials that may manage that user's keys and `gh` signed in.
# The secret key is never printed or written to disk. Also used for the yearly rotation:
# ROTATE=1 deletes the user's other key after the new one is stored.
set -euo pipefail
OWNER=${OWNER:-ayenisholah}
USER_NAME=feedwatch-deployer
REPOS=(feedwatch-platform feedwatch-poller feedwatch-api feedwatch-web)
export AWS_REGION=eu-north-1

old_keys=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
if [ "$(wc -w <<<"$old_keys")" -ge 2 ]; then
  echo "$USER_NAME already has two keys ($old_keys). Delete one first." >&2
  exit 1
fi

key_json=$(aws iam create-access-key --user-name "$USER_NAME" --output json)
field() { python3 -c "import json,sys; print(json.load(sys.stdin)['AccessKey']['$1'], end='')" <<<"$key_json"; }
key_id=$(field AccessKeyId)

for repo in "${REPOS[@]}"; do
  field AccessKeyId | gh secret set AWS_ACCESS_KEY_ID --repo "$OWNER/$repo"
  field SecretAccessKey | gh secret set AWS_SECRET_ACCESS_KEY --repo "$OWNER/$repo"
  echo "stored in $OWNER/$repo"
done
unset key_json

if [ "${ROTATE:-}" = "1" ]; then
  for old in $old_keys; do
    aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$old"
    echo "deleted old key $old"
  done
fi
echo "Done: key $key_id is in ${#REPOS[@]} repos. Start a deploy with: gh workflow run Deploy --repo $OWNER/feedwatch-platform"
