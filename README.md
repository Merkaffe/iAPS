# OmnipodKit

A universal Omnipod pump manager to (eventually) handle all Insulet Omnipod pod types.
A short-term goal of this effort is to replace both the OmniKit and OmniBLE pump managers
with a single pump manager which to handle all Omnipod pod types
to simplify future DIY Omnipod code maintenance and to improve the user
experience when switching between different Omnipod pod types.
The longer-term goal is that this Omnipod pump manager will be extended
to provide Omnipod 5 support as a third pod type option for both Loop and Trio.

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

### March 17, 2025

At this time, there is nothing implementing Omnipod 5 communications
which is still trying to be understood by the DIY community.
The O5 support is temporary placeholder and verification code using the DASH
transport to test having a third pod type showing new Omnipod 5 UI additions
(different text, pod tab color, etc)
and using an alternate base pod id in the pod comms.
For DIY use, the Omnipod 5 pod ids will start with 0x15
while the DIY DASH pod ids will start with 0x17.
Eros addresses (pod ids) for both DIY and PDM use always start with 0x1F.

The pump settings show the name of the selected pod type.
Pod Diagnostics -> Pump Manager Details can be used
to examine the attributes of the new unified Pump Manager & pod state used by OmnipodKit.

### To Do

Figure out possible future migration aids to help transition pod use
to OmnnipodKit while deprecating use of OmniKit and OmniBLE.

Figure out the Omnipod 5 encryption and transport and
update OmnpodKit to actually fully support this pod type!

## To Add to LoopWorkspace

In the near future that will be a patch which can be run to automatically handle
the few integration issues of OmnipodKit to a modern LoopWorkspace.
In the meantime a manual add to LoopWorkspace can be easily performed.

#### To Manually Add to LoopWorkspace

```quote
$ cd <the-top-of-LoopWorkspace-directory>
$ git clone https://github.com/loopandlearn/OmnipodKit.git
$ xed .

In Xcode, select File->'Add Files to "LoopWorkspace"...'
Scroll down to select and double click to open the "OmnipodKit" directory
Select the "OmnipodKit.xcodeproj" file and tap the blue (Add) button
Tap the blue (Finish) button

In Xcode with the LoopWorkspace selected, select Product->Scheme->Edit Scheme...
Make sure that the Build tab on the top of the left panel is selected
Click on the "+" in the bottom left corner above the blue (Duplicate Scheme) button
Scroll down to select "OmnipodKitPlugin" icon (under OmnipodKit) and tap the blue (Add) button
Drag "OmnipodKitPlugin OmnipodKit" from the bottom of the list up until immediately before "OmniKitPlugin OmniKit"
Tap (Close)
```
After signing and building Loop, be sure to select the new "All Omnipod Types"
when doing an "Add Pump" to use the new OmnipodKit pump manager.

To add the OmniTests to the LoopWorkspace tests,
verify that the LoopWorkspace is selected,
click on the diamond with the check near the top
of the lefthand panel to display the Test Navigator panel,
right click on OmniTests under the "Other Tests" section near the end of the panel,
and then select "Add to LoopWorkspace".

## To Add to Trio-dev

Unfortunately Trio requires editing multiple Trio source files to incorporate a Pump Manager,
and even more edits are required for a successful addition of
any Omnipod Pump Manager (OmniBLE, OmniKit or OmnipodKit).
There is patch to handle all the Trio pump manager integration requirements to add the
OmnipodKit (private repo) pump manager to the closed-beta Trio-dev (private repo).

```quote
$ cd <the-top-of-a-buildable-Trio-dev-directory>
$ git clone https://github.com/loopandlearn/OmnipodKit.git
$ git apply OmnipodKit/patch/add_omnipodkit_to_Trio-dev.patch
```

It is expected that the Trio-dev repository will become public before the OmnipodKit repo.
