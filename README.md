# OmniCore

A prototype unified pump manager to (eventually) handle all Omnipod pod types

N.B., Extremely early & incomplete prototyping work -- do not use for live use!

When doing an "Add Pump", select "All Omnipod Types" to select the OmniCore pump manager.
The actual Omnipod pod type will be selected during the pump manager initialization sequence.
When there is no pod, you can switch to use a different pod type OR another different pump manager
by scrolling to the bottom of the pump settings view and tapping on "Switch to another pod or pump type". The "Omnipod" (OmniKit) and "Omnipod DASH" (OmniBLE) pump managers are
still the original unmodified pump managers which maintain their own separate pump manager state.
Eventually the OmniKit and OmniBLE pump managers and their associated plugins should hopefully be totally replaced by OmniCore.


## Status
#### February 13, 2025

The pump settings will show the name of the select pod type. Pod Diagnostics -> Pump Manager Details can be used to examine the new state attributes of the new unified pump manager & pod state. The iPhone simulators work for basic pod setup & deactivation cycles for Eros, Dash & Omnipod 5. As always with OmniKit and OmniBLE, there is no actual simulated pod comms and thus no fake closed loop use can be tried using iPhone simulators.

+ Eros:   PodComms and MessageTransport are not completed & will hang if pairing is attempted
+ DASH:   Fully working, but so far only tested with an rPi pod sim
+ O5:     Temp code using DASH commons that only has been testing with an rPi pod sim (i.e., it's really a DASH controller to the pod), but it will show new Omnipod 5 UI additions (different text, pod tab color, etc) and using an alternate base pod id in the pod comms. Note that the DIY  O5 pod ids start with 0x15 while DIY DASH pod ids start with 0x17. Eros addresses (pod ids) for DIY and PDMs always start with 0x1F.

## To Install
Temporary hack install instructions. Subject to future change.
```quote
$ git clone --branch=dev --recurse-submodules https://github.com/LoopKit/LoopWorkspace.git
$ cd LoopWorkspace/RileyLinkKit
$ git remote add lal https://github.com/loopandlearn/RileyLinkKit.git
$ git fetch lal
$ git checkout oc_tweaks
$ cd ..
$ xed .
```

+ In Xcode, select File->'Add Files to "LoopWorkspace"...'
+ Scroll down to select and open the "OmniCore" directory
+ Select the "OmniCore.xcodeproj" file and tap the blue (Add) button
+ For the "Choose options for adding these files" dialog,
  leave Action as "Reference files in place" and tab blue (Finish) button.


+ In Xcode, select Product->Scheme->Edit Scheme...
+ Make sure that the Build tab on the top of the left panel is selected
+ Click on "+" in the bottom left corner above the blue (Duplicate Scheme) button
+ Scroll down to select "OmniCorePlugin" and tap (Add)
+ Drag "OmniCorePlugin" from the bottom up to after "MinimedKitPlugin" and before "OmniKitPlugin"
Tap (Close)
