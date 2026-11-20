"""Check actual built launcher identity/entrypoints and preserve license evidence."""
import hashlib,json,plistlib,sys,zipfile
from pathlib import Path
path=Path(sys.argv[1])
with zipfile.ZipFile(path) as archive:
    assert archive.testzip() is None
    info=plistlib.loads(archive.read('Payload/SideStore.app/Info.plist'))
    assert info['CFBundleIdentifier']=='com.rosnewgen.launcher'
    assert info['CFBundleDisplayName']=='NEWG Launcher'
    assert info['CFBundleShortVersionString']=='0.1.0'
    schemes=[s for t in info['CFBundleURLTypes'] for s in t['CFBundleURLSchemes']]
    assert 'newg-launcher' in schemes and 'sidestore' in schemes
    assert 'NEWGGameRelease' not in info,'Owner URL must not be in public artifacts'
    native=archive.read('Payload/SideStore.app/'+info['CFBundleExecutable'])
    assert b'ROS NEW GENERATION' in native and b'Verifying the complete IPA' in native
    assert any(n.endswith('SideBackup.ipa') for n in archive.namelist())
with path.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
receipt={'bytes':path.stat().st_size,'sha256':digest,'bundle_id':info['CFBundleIdentifier'],
         'version':info['CFBundleShortVersionString'],'zip_crc_verified':True,'native_newg_ui_present':True,
         'unsigned_requires_personal_signing':True,'apple_credentials_included':False,
         'phone_install_or_renewal_verified':False,'source':'https://github.com/dvshaoo/newg-launcher',
         'upstream':'SideStore/SideStore 0.6.4 f93a95c079057090bea355453ef24f6e8668dfa9','license':'AGPL-3.0-only'}
Path('newg-package-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
