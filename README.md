# OmnipodKit

A prototype unified pump manager to (eventually) handle all Omnipod pod types!
Note that this is an early & incomplete prototyping work -- use at your own risk!

When doing an "Add Pump", select "All Omnipod Types" to select the new OmnipodKit pump manager.
The actual Omnipod pod type will be selected during the pump manager initialization sequence.
When there is no pod, you can switch to use a different pod type OR another different pump manager
by scrolling to the bottom of the pump settings view and tapping on "Switch to another pod or pump type".
The "Omnipod" (OmniKit) and "Omnipod DASH" (OmniBLE) pump managers displayed by "Add Pump" are
still the original unmodified pump managers which maintain their own separate pump manager state.
Eventually the OmniKit and OmniBLE pump managers and their associated plugins should be totally replaced by OmnipodKit.

The names used this repo and its plugin module identifier are still subject to change.

## Status
#### February 23, 2025

The way to deal with different transports types is currently pretty hacky and will be getting reworked.

There are still pending decisions to be make about what to do with the DeliveryUncertaintyRecoveryView.

There is nothing implementing Omnipod 5 communications yet which is still trying to be understood.
Eventually this OmnipodKit pump manager will be providing the eventual Omnipod 5 support for Loop.

+ Eros:   Looping with Eros pods
+ DASH:   Looping with DASH pods and pod sim
+ O5:     Looping with DASH pods and pod sim (for testing purposes). This is temp code using DASH transport to test having a 3rd pod type showing new Omnipod 5 UI additions (different text, pod tab color, etc) and using an alternate base pod id in the pod comms. For DIY O5 pod ids will start with 0x15 while DIY DASH pod ids start with 0x17. Eros addresses (pod ids) for both DIY and PDM use always start with 0x1F.

The iPhone simulators work for basic pod setup & deactivation cycles for Eros, Dash & Omnipod 5.
As always was for the Omnipod pump managers with the iPhone simulator, there are no actual simulated pod comms and thus no fake closed loop use can be simulated using iPhone simulators.

The pump settings will show the name of the select pod type.
Pod Diagnostics -> Pump Manager Details can be used to examine
the new state attributes of the new unified pump manager & pod state.

## To Add to a fresh Loop Workspace
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

## To Add to Tri
Unfortunately Trio has some special case code for dealing with the OmniKit and OmniBLE Pump Managers.
Additionally Trio isn't currently set up to handle plugin pump managers gracefally in the general case.
So a number of Trio changes are needed to add the OmnipodKit Pump Manager to the Trio app.
Marion Barker has already done this and can provide more information and a version of Trio
with all the needed mods to add the current version of the OmnipodKit Pump Manager to Trio.

