# OmnipodKit

OmnipodKit is a new universal Omnipod pump manager that

* Handles both the Eros and DASH pod types
* Hopefully will eventually support the Omnipod 5 (O5)
* Simplifies future DIY Omnipod code maintenance
* Has a number of improvements and updates

To select the new OmnipodKit pump manager,
select `All Omnipod Types` when doing an `Add Pump`.
The actual Omnipod pod type will be selected during
the pump manager initialization setup sequence.
After deactivating a pod when using the OmnipodKit pump manager,
you can switch to either a different pod type OR
to another completely different pump manager
by scrolling to the bottom of the pod settings view and tapping on
`Switch to another pod or pump type`.

The `Omnipod` (OmniKit) and `Omnipod DASH` (OmniBLE) pump managers
currently displayed with `Add Pump` are the original unmodified
pump managers which maintain their own separate pump manager state.
Therefore if you already have an active pod session using a previous pump manager,
you must select `Switch to other insulin delivery device`
after deactivating any active pod before you can do an `Add Pump`
to select `All Omnipod Types` for the OmnipodKit pump manager.
Eventually the OmniKit and OmniBLE pump managers
will be totally replaced by OmnipodKit.
When this happens, OmnipodKit will handle any conversion of
any OmniKit or OmniBLE state (including for a currently active pod)
and the OmniKit and OmniBLE pump managers
will no longer be available or supported.


## Status as of January 20, 2026

Since the OmnipodKit repository is still private
and limited to selected developers,
`Omnipod 5` is available as a selection in the `Omnipod Type` view
even though it is not working as the encryption used in the
pairing sequence is not yet understood enough to do O5 pod pairing.
The `Omnipod 5` choice should not be selected except
for developers doing Omnipod 5 DIY development work.
If OmnipodKit is made public before the O5 code
is ready for possible limited test use,
the `Omnipod Type` view will be modified to display
only the `Omnipod Classic` and `Omnipod DASH` pod types.


## Developer Notes

The Omnipod 5 pod ids (addresses) will start with 0x15
while the DIY DASH pod ids will continue to start with 0x17.
Eros addresses (pod ids) start with 0x1F for both DIY and PDM.
The pump settings shows the name of the selected pod type.
`Pod Diagnostics` -> `Pump Manager Details` can be used
to examine details of attributes of the new unified
Pump Manager and Pod state used by OmnipodKit.

OmnipodKit/OmnipodKit/Bluetooth/BluetoothServices.swift
currently has a number of total hacks to rapidly
handle a number of DASH versus O5 Bluetooth differences.
Eventually parts of OmnipodKit/OmnipodKit/Bluetooth
will be refactored to a more reasonable form once more
of the O5 communication differences are better understood.
The setServicePodType() func currently is used to
set a number of temporary variables that are used
to control several aspects of the Bluetooth communications.
The OmnipodKit/OmnipodKit/Bluetooth/Pair/O5LTKExchanger.swift
file has code for the early part of what's understood
about the O5 pairing sequence and will need to be extended.


## To Add to LoopWorkspace

Included in the OmnipodKit repository is the patch to add the OmnipodKit (private repo) pump manager to a fresh clone of [LoopWorkspace](https://github.com/LoopKit/LoopWorkspace/).

* This patch is valid for either `main` or `dev` branches for LoopWorkspace.

The commands below should be pasted into Terminal with the path at the top-of-a-buildable LoopWorkspace directory.

If LoopWorkspace is open in Xcode, then before executing these commands:

* select Product, Clean Build Folder
* select File, Close Workspace

```
git switch -c add_omnipodkit_loop
git submodule add https://github.com/loopandlearn/OmnipodKit
git apply OmnipodKit/patches/add_omnipodkit_to_LoopWorkspace.patch
git add .
git commit -am "add submodule OmnipodKit"
xed .
```

When Xcode opens, if questioned, select use the version on disk.

After building Loop, be sure to select the new `All Omnipod Types`
when doing an `Add Pump` to use the new OmnipodKit pump manager.

## To Add to the Public Beta for Trio

Included in the OmnipodKit repository is the patch to add OmnipodKit to a fresh clone of [Trio](https://github.com/nightscout/Trio/).

* This patch only works with the open beta, Trio 0.6.x, `dev` branch
* This patch does not work with Trio 0.2.x, `main` branch

The commands below should be pasted into Terminal with the path at the top-of-a-buildable Trio directory.
This patch handles all the Trio pump manager integration requirements to add the
OmnipodKit (private repo) pump manager to the open-beta Trio, `dev` branch.

If Trio is open in Xcode, then before executing these commands:

* select Product, Clean Build Folder
* select File, Close Workspace

```
git switch -c add_omnipodkit_trio
git submodule add https://github.com/loopandlearn/OmnipodKit
git apply OmnipodKit/patches/add_omnipodkit_to_Trio.patch
git add .
git commit -am "add submodule OmnipodKit"
xed .
```

When Xcode opens, if questioned, select use the version on disk.

After building with Xcode, this file will be modified as well: `Trio/Sources/Localizations/Main/Localizable.xcstrings`

After building Loop, be sure to select the new `All Omnipod Types`
when doing an `Add Pump` to use the new OmnipodKit pump manager.

## To Add to the Private Repository Trio-dev

Included in the OmnipodKit repository is the patch to add OmnipodKit to a fresh clone of [Trio](https://github.com/nightscout/Trio-dev/). Because this is a private repository, most people will not have access to it.

The commands below should be pasted into Terminal with the path at the top-of-a-buildable Trio directory.
This patch handles all the Trio pump manager integration requirements to add the
OmnipodKit (private repo) pump manager to Trio-dev (private repo).

If Trio is open in Xcode, then before executing these commands:

* select Product, Clean Build Folder
* select File, Close Workspace

```
git switch -c add_omnipodkit_trio-dev
git submodule add https://github.com/loopandlearn/OmnipodKit
git apply OmnipodKit/patches/add_omnipodkit_to_Trio-dev.patch
git add .
git commit -am "add submodule OmnipodKit"
xed .
```

When Xcode opens, if questioned, select use the version on disk.

After building with Xcode, this file will be modified as well: `Trio/Sources/Localizations/Main/Localizable.xcstrings`

After building Loop, be sure to select the new `All Omnipod Types`
when doing an `Add Pump` to use the new OmnipodKit pump manager.

## Manually Add a Plugin to LoopWorkspace

This section is kept for future reference on how to add a new plugin to Loop. **When you use the patch method, above, this section is not required.**

**This plugin addition is not used for Trio.**

```quote
$ cd <the-top-of-LoopWorkspace-directory>
$ git submodule add https://github.com/loopandlearn/OmnipodKit
$ xed .

In Xcode, select File->'Add Files to "LoopWorkspace"...'

* Scroll down to select and double click to open the "OmnipodKit" directory
* Select the "OmnipodKit.xcodeproj" file and tap the blue (Add) button
* Tap the blue (Finish) button

In Xcode with the LoopWorkspace selected, select Product->Scheme->Edit Scheme...

* Make sure that the Build tab on the top of the left panel is selected
* Click on the "+" in the bottom left corner above the blue (Duplicate Scheme) button
* Scroll down to select "OmnipodKitPlugin" icon (under OmnipodKit) and tap the blue (Add) button
* Drag "OmnipodKitPlugin OmnipodKit" from the bottom of the list up until immediately before "OmniKitPlugin OmniKit"
* Tap (Close)

To add the OmniTests to the LoopWorkspace tests in Xcode:

* verify that the LoopWorkspace scheme is selected
* click on the diamond with the check near the top of the lefthand panel to display the Test Navigator panel
* right click on OmniTests under the "Other Tests" section near the end of the panel
* select "Add to LoopWorkspace".

```

## Manually Add a Pump Manager to Trio

This section is kept for future reference on how to add a new pump manager to Trio. **When you use the patch method, above, this section is not required.**

Trio does not use the plugin features used by Loop.

In addition, Trio requires editing multiple Trio source files to incorporate a Pump Manager,
and even more edits are required for a successful addition of
any Omnipod Pump Manager (OmniBLE, OmniKit or OmnipodKit). **Review the patch for Trio edits.**

```quote
$ cd <the-top-of-Trio-directory>
$ git submodule add https://github.com/loopandlearn/OmnipodKit
$ xed .

In Xcode, select File->'Add Files to "Trio"...'

* Scroll down to select and double click to open the "OmnipodKit" directory
* Select the "OmnipodKit.xcodeproj" file and tap the blue (Add) button
* Tap the blue (Finish) button

Now the framework for OmnipodKit must be added explicitly
 (this is instead of the plugin steps from LoopWorkspace above).

In Xcode, tap on the Trio Target

* Make sure the General Tab is open
* Scroll to Frameworks, Libraries, and Embedded Content
* At the bottom of the list, tap on + and select OmnipodKit.framework
* Clean the build folder, Close and Open workspace

At the current time, do not add the OmniTests to the Trio tests in Xcode; this will be dealt with at a later time.

```

The following files must be edited for Trio to work with the new pump manager.
Examine the `add_omnipodkit_to_Trio-dev.patch` to view the required changes.

* Trio/Sources/APS/DeviceDataManager.swift
* Trio/Sources/Modules/Home/View/HomeRootView.swift
* Trio/Sources/Modules/PumpConfig/PumpConfigDataFlow.swift
* Trio/Sources/Modules/PumpConfig/View/PumpConfigRootView.swift
* Trio/Sources/Modules/PumpConfig/View/PumpSetupView.swift
* scripts/swiftformat.sh

The change in `scripts/swiftformat.sh` prevents the application of Trio linting rules to the OmnipodKit submodule.
