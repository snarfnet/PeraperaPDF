import jwt, time, requests, sys

KEY_ID = 'WDXGY9WX55'
ISSUER = '2be0734f-943a-4d61-9dc9-5d9045c46fec'
APP_ID = '6766239057'
PRIVACY_URL = 'https://snarfnet.github.io/'
BUILD_NUMBER = sys.argv[1]

REVIEW_CONTACT = {
    'contactFirstName': '聖',
    'contactLastName': '尼崎',
    'contactEmail': 'tokyonasu@yahoo.co.jp',
    'contactPhone': '+81 80-2368-9194',
}

p8 = open('/tmp/asc_key.p8').read()

def make_token():
    return jwt.encode(
        {'iss': ISSUER, 'iat': int(time.time()), 'exp': int(time.time()) + 1200, 'aud': 'appstoreconnect-v1'},
        p8, algorithm='ES256', headers={'kid': KEY_ID}
    )

def headers():
    return {'Authorization': f'Bearer {make_token()}', 'Content-Type': 'application/json'}

def api(method, path, **kwargs):
    r = requests.request(method, f'https://api.appstoreconnect.apple.com/v1{path}',
                         headers=headers(), **kwargs)
    if not r.ok:
        print(f'ERROR {r.status_code}: {r.text}')
        sys.exit(1)
    return r.json() if r.text else {}

# ビルド待機
print('Waiting for build...')
for _ in range(40):
    builds = api('GET', f'/builds?filter[app]={APP_ID}&filter[version]={BUILD_NUMBER}&limit=1')
    items = builds.get('data', [])
    if items:
        build_id = items[0]['id']
        state = items[0]['attributes']['processingState']
        print(f'Build {build_id}: {state}')
        if state == 'VALID':
            break
    time.sleep(30)
else:
    print('Timed out waiting for build')
    sys.exit(1)

# Export compliance
api('PATCH', f'/builds/{build_id}', json={
    'data': {'type': 'builds', 'id': build_id,
             'attributes': {'usesNonExemptEncryption': False}}
})

# contentRightsDeclaration
api('PATCH', f'/apps/{APP_ID}', json={
    'data': {'type': 'apps', 'id': APP_ID,
             'attributes': {'contentRightsDeclaration': 'DOES_NOT_USE_THIRD_PARTY_CONTENT'}}
})

# privacyPolicyUrl を appInfoLocalizations に設定
app_infos = api('GET', f'/apps/{APP_ID}/appInfos')
for info in app_infos.get('data', []):
    locs = api('GET', f'/appInfos/{info["id"]}/appInfoLocalizations')
    for loc in locs.get('data', []):
        loc_id = loc['id']
        api('PATCH', f'/appInfoLocalizations/{loc_id}', json={
            'data': {'type': 'appInfoLocalizations', 'id': loc_id,
                     'attributes': {'privacyPolicyUrl': PRIVACY_URL}}
        })

# バージョン取得
versions = api('GET', f'/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION')
if not versions['data']:
    versions = api('GET', f'/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=WAITING_FOR_REVIEW,IN_REVIEW,READY_FOR_SALE')
    if versions['data']:
        print('Already submitted or in review, skipping')
        sys.exit(0)
    print('No version found')
    sys.exit(1)

version_id = versions['data'][0]['id']

# レビュー詳細（連絡先 + デモアカウント不要）
rd_attrs = {**REVIEW_CONTACT, 'demoAccountRequired': False, 'demoAccountName': '', 'demoAccountPassword': ''}
review_details = api('GET', f'/appStoreVersions/{version_id}/appStoreReviewDetail')
if review_details.get('data'):
    rd_id = review_details['data']['id']
    api('PATCH', f'/appStoreReviewDetails/{rd_id}', json={
        'data': {'type': 'appStoreReviewDetails', 'id': rd_id, 'attributes': rd_attrs}
    })
else:
    api('POST', '/appStoreReviewDetails', json={
        'data': {'type': 'appStoreReviewDetails',
                 'attributes': rd_attrs,
                 'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': version_id}}}}
    })

# ビルドをバージョンに紐付け
api('PATCH', f'/appStoreVersions/{version_id}', json={
    'data': {'type': 'appStoreVersions', 'id': version_id,
             'relationships': {'build': {'data': {'type': 'builds', 'id': build_id}}}}
})

# 審査提出
review = api('POST', '/reviewSubmissions', json={
    'data': {'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'},
             'relationships': {'app': {'data': {'type': 'apps', 'id': APP_ID}}}}
})
review_id = review['data']['id']

api('POST', '/reviewSubmissionItems', json={
    'data': {'type': 'reviewSubmissionItems',
             'relationships': {'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': review_id}},
                               'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': version_id}}}}
})

api('PATCH', f'/reviewSubmissions/{review_id}', json={
    'data': {'type': 'reviewSubmissions', 'id': review_id,
             'attributes': {'submitted': True}}
})

print('Submitted for review!')
