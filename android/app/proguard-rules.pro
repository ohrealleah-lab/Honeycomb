# Project-specific R8/ProGuard rules for release builds (minifyEnabled = true).
#
# Intentionally empty for now: kotlinx.serialization, Compose, DataStore and Coil all
# ship their own consumer keep rules, and this app loads nothing by reflection.
# Add rules here only for something R8 strips that the app needs at runtime
# (e.g. a class looked up by name) — verify with a release build on a device.
