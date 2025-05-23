# OmnipodKit

OmnipodKit is a universal Omnipod pump manager to (eventually) handle all Insulet Omnipod pod types.

A short-term goal of this effort is to replace both the OmniKit and OmniBLE pump managers
with a single pump manager to

* handle all Omnipod pod types
* simplify future DIY Omnipod code maintenance
* improve the user experience when switching between different Omnipod pod types

The longer-term goal is that the OmnipodKit pump manager provide Omnipod 5 (O5) support as a third pod type option for both Loop and Trio when, and if, the O5 encryption is understood well enough to enable pairing a DIY app to an O5 pod.

To use this new OmnipodKit pump manager, select "All Omnipod Types" when doing an "Add Pump".
The actual Omnipod pod type will be selected during the pump manager initialization sequence.
After deactivating a pod when using the OmnipodKit pump manager,
you can switch to either a different pod type OR another different pump manager
by scrolling to the bottom of the pod settings view and tapping on
"Switch to another pod or pump type".

The "Omnipod" (OmniKit) and "Omnipod DASH" (OmniBLE) pump managers
displayed with "Add Pump" are still the original unmodified
pump managers which maintain their own separate pump manager state.
Therefore if you already have an active pod session using a previous pump manager,
you must select "Switch to other insulin delivery device" after deactivating any active pod
before you can do an "Add Pump" to select "All Omnipod Types" for the OmnipodKit pump manager.
Eventually the OmniKit and OmniBLE pump managers and their associated plugins
should be totally replaced by OmnipodKit.

![Screen for changing pod or pump type](img/OmnipodKit_pod_selection.png)

Note that OmnipodKit is still an evolving prototype -- use at your own risk!

## Status

### 2025 May 22

Update the README file after the open beta testing for Trio 0.5.x was made available 2025 May 17. 
No other changes are needed to OmnipodKit.

### 2025 March 20

At this time, there is nothing implementing Omnipod 5 communications.

> The O5 selection option is a temporary placeholder. It uses the DASH
transport and will work with both an actual DASH pod and with the [rPi DASH simulator](https://github.com/LoopKit/pod). This enables configuring Omnipod 5 UI additions
(different text, pod tab color, etc)
and using an alternate base pod id in the pod comms, while using the known transport for DASH pods.

For DIY use, the Omnipod 5 pod ids will start with 0x15
while the DIY DASH pod ids will start with 0x17.
Eros addresses (pod ids) start with 0x1F for both DIY and PDM.

The pump settings show the name of the selected pod type.
Pod Diagnostics -> Pump Manager Details can be used
to examine the attributes of the new unified Pump Manager & pod state used by OmnipodKit.

### To Do

Figure out possible future migration aids to help transition pod use
to OmnnipodKit while deprecating use of OmniKit and OmniBLE.

Figure out the Omnipod 5 encryption and transport and
update OmnpodKit to actually fully support this pod type!

## To Add to LoopWorkspace

Included in the OmnipodKit repository is the patch to add the OmnipodKit (private repo) pump manager to a fresh clone of [LoopWorkspace](https://github.com/LoopKit/LoopWorkspace/).

* This patch is valid for either `main` or `dev` branches for LoopWorkspace.

The commands below should be pasted into Terminal with the path at the top-of-a-buildable LoopWorkspace directory.

If LoopWorkspace is open in Xcode, then before executing these commands:

* select Product, Clean Build Folder
* select File, Close Workspace

```
git switch -c add_omnipodkit
git submodule add https://github.com/loopandlearn/OmnipodKit
git apply OmnipodKit/patches/add_omnipodkit_to_LoopWorkspace.patch
git add .
git commit -am "add submodule OmnipodKit"
xed .
```

When Xcode opens, if questioned, select use the version on disk.

After building Loop, be sure to select the new "All Omnipod Types"
when doing an "Add Pump" to use the new OmnipodKit pump manager.


## To Add to Trio

Included in the OmnipodKit repository is the patch to add OmnipodKit to a fresh clone of [Trio](https://github.com/nightscout/Trio/).

* This patch only works with the open beta, Trio 0.5.x, `dev` branch
* This patch does not work with the released version of Trio (0.2.x). `main` branch.

The commands below should be pasted into Terminal with the path at the top-of-a-buildable Trio directory. 
This patch handles all the Trio pump manager integration requirements to add the
OmnipodKit (private repo) pump manager to the open-beta Trio, `dev` branch.

If Trio is open in Xcode, then before executing these commands:

* select Product, Clean Build Folder
* select File, Close Workspace

```
git switch -c add_omnipodkit
git submodule add https://github.com/loopandlearn/OmnipodKit
git apply OmnipodKit/patches/add_omnipodkit_to_Trio-dev.patch
git add .
git commit -am "add submodule OmnipodKit"
xed .
```

When Xcode opens, if questioned, select use the version on disk.

After building with Xcode, this file will be modified as well: `Trio/Sources/Localizations/Main/Localizable.xcstrings`

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
