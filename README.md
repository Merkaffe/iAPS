# OmniCore

A prototype unified pump manager to (eventually) handle all Omnipod pod types

N.B., Extremely early & incomplete prototyping work -- do not use for live use!

When doing an "Add Pump", select "All Omnipod Types" to select the OmniCore pump manager.
The actual Omnipod pod type will be selected during the pump manager initialization sequence.
When there is No Pod, you can switch to another pod type OR another different pump manager
by scrolling to the bottom of the pump settings view and tapping on "Switch to another pod or pump type".
The "Omnipod" (OmniKit) and "Omnipod DASH" (OmniBLE) pump managers are
still the original unmodified pump managers that maintain their own separate pump manager state.
Eventually the OmniKit and OmniBLE pump managers and their plugins should hopefully be totally replaced by OmniCore.


## Status
### As of February 12, 2025
    iPhone simulators: Works for pod setup & deactivation cycles for Eros, Dash & O5
    Eros: PodComms and MessageTransport not completed, will hang if Pairing is attempted
    DASH: full working, but so far only tested with rPi
    O5:   working placeholder that works with DASH pods, but using all the O5 UI updates and a new base pod id


## To Install
$ git clone --branch=dev --recurse-submodules https://github.com/LoopKit/LoopWorkspace.git
$ cd LoopWorkspace
$ rm -rf RileyLinkKit
$ git clone --branch=oc_tweaks https://github.com/loopandlearn/RileyLinkKit
$ git clone https://github.com/loopandlearn/OmniCore.git
$ xed .

In Xcode, select File->'Add Files to "LoopWorkspace"...'
Select OmniCore/OmniCore.xcodeproj & tap (Add)
Action: "Reference files in place"
Tap (Finish)

In Xcode, select Product->Scheme->Edit Scheme...
Click on "+"
Scroll down to select "OmniCorePlugin" and tap (Add)
Then drag "OmniCorePlugin" up to after MimemedPlugin and before OmniKitPlugin
Tap [Close]

