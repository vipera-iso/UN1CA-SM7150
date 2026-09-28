# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# Debloat list for Qualcomm Snapdragon 730G devices (sm7150)
# - Add entries inside the specific partition containing that file (<PARTITION>_DEBLOAT+="")
# - DO NOT add the partition name at the start of any entry (eg. "/system/dpolicy_system")
# - DO NOT add a slash at the start of any entry (eg. "/dpolicy_system")

# Overlays
SYSTEM_DEBLOAT+="
system/app/WifiRROverlayAppLls
"

# mAFPC
SYSTEM_DEBLOAT+="
system/bin/mafpc_write
"

# HDCP
SYSTEM_DEBLOAT+="
system/bin/dhkprov
system/bin/qchdcpkprov
system/etc/init/dhkprov.rc
system/lib64/vendor.samsung.hardware.security.hdcp.keyprovisioning@1.0.so
"

# Apps debloat
SYSTEM_DEBLOAT+="
system/etc/permissions/privapp-permissions-com.samsung.android.app.earphonetypec.xml
system/priv-app/EarphoneTypeC
system/priv-app/IntelligentDynamicFpsService
system/priv-app/SamsungPositioning
system/priv-app/OMCAgent5
"

# GameDriver
SYSTEM_DEBLOAT+="
system/priv-app/GameDriver-SM8450
"

# system_ext clean-up
SYSTEM_EXT_DEBLOAT+="
etc/permissions/com.qti.location.sdk.xml
etc/permissions/com.qualcomm.location.xml
etc/permissions/privapp-permissions-com.qualcomm.location.xml
framework/com.qti.location.sdk.jar
priv-app/com.qualcomm.location
"

# vendor clean-up
VENDOR_DEBLOAT+="
etc/cgroups.json
"
# Lean additions (LostPrime lean build) — extra Samsung bloat for OC headroom
SYSTEM_DEBLOAT+="
system/priv-app/BixbyWakeup
system/app/BixbyVoiceDropbox
system/priv-app/BixbyVisionFramework
system/priv-app/BixbyVoice
system/app/GlobalGoals
system/priv-app/SamsungMembers
system/priv-app/SCloud
system/app/GalaxyFriends
system/app/SamsungTTS
system/app/DiagMonAgent
system/app/SamsungDMSAgent
system/priv-app/Fmm
system/app/SPDClient
system/app/WssyncmlDm
system/priv-app/SysScope
system/app/KnoxAttestation
system/app/ContainerAgent
"
