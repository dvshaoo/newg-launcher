# NEWG Launcher — owner phone pilot

Modified from SideStore stable 0.6.4, commit
f93a95c079057090bea355453ef24f6e8668dfa9. Licensed under the original GNU AGPLv3;
all upstream copyright and license notices are retained. This is an independent
NEWG fork, not an official SideStore release.

The native NEWG home starts the original Apple Account sign-in and app renewal
flows. Verified ROS downloads are handed to the original SideStore native
sign/install confirmation. NEWG validates release origin, target bundle, size
and complete SHA-256 before handing a download to installation.

Each tester uses their own Apple Account. Initial PC installation and device
pairing are required. LocalDevVPN and Wi-Fi are required for on-device renewal.
An expired launcher or invalid pairing may need PC recovery. Free Apple limits
still apply; this does not extend seven-day provisioning or bypass revocation.

The pilot uses `com.rosnewgen.launcher`, its own update source, and retains the
upstream Apple sign-in, Keychain, pairing, minimuxer and refresh implementation.
The original news tab is replaced; My Apps, settings and their tab positions
remain intact. Upstream scheduled/release workflows are archived as disabled
files; only a manually dispatched macOS build is enabled.

Public source/builds contain no Apple accounts, pairing files, certificates,
private signing keys, ROS binary, or private ROS download URLs. The owner pilot
release descriptor is added to the unsigned IPA locally, after CI. An updated
NEWG release JSON can be imported through Files without rebuilding the launcher.

Build: dispatch `.github/workflows/newg-pilot.yml` on `newg-pilot`. The standard
public macOS runner compiles and checks the actual unsigned package. Its ad-hoc
signature only preserves entitlement metadata; installation still requires the
owner's valid personal Apple signing/provisioning during initial PC setup.

Phone installation, Apple Account authentication, pairing and real on-device
self-renewal must be verified before claiming this pilot works for testers.
Do not uninstall existing ROS or send Apple passwords to a NEWG website.

Upstream setup: https://docs.sidestore.io/docs/installation/prerequisites.html

Source: https://github.com/dvshaoo/newg-launcher
