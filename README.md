# OmnipodKit

OmnipodKit is a new universal Omnipod pump manager that

* Handles all supported Omnipod types
* Simplifies future DIY Omnipod code maintenance
* Has a number of improvements and updates for Omnipod support
* Will be replacing both OmniKit (Eros) and OmniBLE (Dash)

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
Currently if you already have an active pod session using a previous pump manager,
you must select `Switch to other insulin delivery device`
after deactivating any active pod before you can do an `Add Pump`
to select `All Omnipod Types` for the OmnipodKit pump manager.
Eventually the OmniKit and OmniBLE pump manager will be replaced by OmnipodKit.
When this happens, OmnipodKit will handle any conversion of
any OmniKit or OmniBLE state (including for a currently active pod)
with minor app changes and the OmniKit and OmniBLE pump managers
will no longer be available and eventually unsupported.

## Status as of March 6, 2026
Pod Details now displays the printed lot information
along with the decimal lot value for all pod types.

A work in progress with many still to be worked out,
but pairing and communications working with real O5 pods
in side branch! No nudge or heartbeat services as of yet,
so time between loop operations can vary a lot without a CGM
providing a "heartbeat" service.

## Status as of January 20, 2026

Since the OmnipodKit repository is still private
and limited to selected developers,
`Omnipod 5` is currently available as a selection
in the `Omnipod Type` view even though it is not working
since the encrypted pairing sequence is not yet
understood well enough to do O5 pod pairing.
The `Omnipod 5` choice should not be selected except
for developers doing Omnipod 5 DIY development work.
If OmnipodKit is made public before the O5 support
is ready for possible limited test use,
the `Omnipod Type` view will be modified to display
only the `Omnipod Classic` and `Omnipod DASH` pod types.


## Developer Notes

The Omnipod 5 (O5) pod ids are still be worked on, but for
now are a limited set of values with a 0x00 in the type byte
DIY DASH pod ids will continue to start with 0x17 and
Eros addresses (pod ids) start with 0x1F in both DIY and PDM.
The pump settings shows the name of the selected pod type.
`Pod Diagnostics` -> `Pump Manager Details` can be used
to examine details of attributes of the new unified
Pump Manager and Pod state used by OmnipodKit.


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
