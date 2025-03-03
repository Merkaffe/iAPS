# OmnipodKit

A prototype universal Pump Manager to (eventually) handle all Omnipod pod types.
Note that this is early & evolving prototyping work -- use at your own risk!

When doing an "Add Pump", select "All Omnipod Types" to select the new OmnipodKit pump manager.
The actual Omnipod pod type will be selected during the pump manager initialization sequence.

After Deactivating a pod, you can switch to use a different pod type OR another different pump manager
by scrolling to the bottom of the pump settings view and tapping on "Switch to another pod or pump type".

![Screen for changing pod or pump type](img/OmnipodKit_pod_selection.png)

The "Omnipod" (OmniKit) and "Omnipod DASH" (OmniBLE) pump managers displayed by "Add Pump" are
still the original unmodified pump managers which maintain their own separate pump manager state. In other words, when you have a pod added using "Omnipod DASH", you must switch to other pump after deactivating and then add the new pump manager by selecting "All Omnipod Types".

Eventually the OmniKit and OmniBLE pump managers and their associated plugins should be totally replaced by OmnipodKit.


## Status

### March 02, 2025

A short-term goal of this effort is to replace both the OmniKit and OmniBLE Pump Managers with a single universal Pump Manager which can handle all
Omnipod pod types to simplify future DIY Omnipod code maintenance and to improve the user experience when switching between different Omnipod pod types.
The longer-term goal is that this Omnipod Pump Manager will be easily extended to provide Omnipod 5 support as a third pod type option for both Loop and Trio.
At this time, there is nothing implementing Omnipod 5 communications which is still trying to be understood by the DIY community.

+ Eros:   Working with basic pod setup & deactivation with iPhone simulators and looping with Eros pods
+ DASH:   Working with basic pod setup & deactivation with iPhone simulators and looping with DASH pods & the rPi pod sim.
    Additionally this has been used for live human use by the author.
+ O5:     Working with basic pod setup & deactivation with iPhone simulators and looping with DASH pods & rthe Pi pod sim (for demo purposes).
   This is temp code using the DASH transport to test having a third pod type showing new Omnipod 5 UI additions (different text, pod tab color, etc) and using an alternate base pod id in the pod comms.
   For DIY use, the Omnipod 5 pod ids will start with 0x15 while the DIY DASH pod ids start with 0x17 and Eros addresses (pod ids) for both DIY and PDM use always start with 0x1F.

The pump settings show the name of the selected pod type. Pod Diagnostics -> Pump Manager Details can be used to examine the attributes of the new unified Pump Manager & pod state.

### Todo

Need to fix Xcode settings to avoid module "not compiled with library evolution support" warnings.

The current method to deal with different transport types is a hack and will be getting reworked.

There are still pending decisions about what to do with DeliveryUncertaintyRecoveryView.

Figure out if it might be possible to do mid pod Omni{BLE,Kit} -> OmnipodKit
Pump Manager conversions which will require special case code to be added within
the DIY apps themselves and the implications of trying to supporting this behavior.

## To Add to a Fresh Loop Workspace

Temporary install instructions.

```quote
$ git clone --branch=dev --recurse-submodules https://github.com/LoopKit/LoopWorkspace.git
$ cd LoopWorkspace
$ git clone https://github.com/loopandlearn/OmnipodKit.git
$ xed .

In Xcode, select File->'Add Files to "LoopWorkspace"...'
Scroll down to select and double click to open the "OmnipodKit" directory
Select the "OmnipodKit.xcodeproj" file and tap the blue (Add) button
Leave the Action as "Reference files in place"
Tap the blue (Finish) button

In Xcode, select Product->Scheme->Edit Scheme...
Make sure that the Build tab on the top of the left panel is selected
Click on the "+" in the bottom left corner above the blue (Duplicate Scheme) button
Scroll down to select "OmnipodKitPlugin" icon (under OmnipodKit) and tap the blue (Add) button
Drag "OmnipodKitPlugin OmnipodKit" from the bottom of the list up until immediately before "OmniKitPlugin OmniKit"
Tap (Close)

Sign and build and give it a try!
Be sure to select "All Omnipod Types" when doing an "Add Pump" to try out the OmnipodKit PumpManager
```

## To Add to Trio-dev

Unfortunately Trio has requires editing parts of the Trio code to incorporate any Pump Manager Plugin, and even more edits are required for successful addition of an Omnipod Pump manager (OmniBLE, OmniKit or OmnipodKit).

The OmnipodKit (private repo) has been successfully added and tested with the closed-beta Trio-dev (private repo).

It is expected that the Trio-dev repository will become public before the OmnipodKit repo, so only the patch needed for Trio-dev is included in this README file.

1. Download the patch, add_omnipodkit_to_Trio-dev.patch, in the patch folder of this repository
2. Nagivate to the Trio-dev folder in your local clone
3. Issue the command below

```
git apply ~/Downloads/add_omnipodkit_to_Trio-dev.patch
```
