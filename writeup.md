---
title: "Fudge 1 year writeup"
author: "Daniel Cook"
date: "June 9 2024"
---
Fudge is an unofficial app that can pair with Fujifilm cameras.
It's an open-source reimplementation of Fuji's official apps, 'Camera Connect' and their 'Xapp'.
The project is one year old today, and is worthy of a writeup.

First of all, let's take a look at Fuji's apps.  
[FUJIFILM Camera Remote on Google Play](https://play.google.com/store/apps/details?id=com.fujifilm_dsc.app.remoteshooter)  
[FUJIFILM Camera Remote on the App Store](https://apps.apple.com/us/app/fujifilm-camera-remote/id793063045)  

The operation of the 'Camera Remote' is pretty typical of IoT pairing apps. You go through the WiFi setup menu on your camera,
follow the instructions on your phone, and you have access to liveview, remote shoot, and all your photos.
Sounds pretty nitfy, but the ratings for this app [tell](https://www.thephoblographer.com/2023/01/11/the-fujifilm-app-is-awful-and-we-didnt-need-a-nintendo-switch-app/) [a](https://www.reddit.com/r/FujifilmX/comments/v81awq/fujifilm_camera_remote_app_is_it_really_that_bad/) [different](https://www.dpreview.com/forums/thread/4691446) [story](https://www.reddit.com/r/fujifilm/comments/yqmoef/why_is_fujis_cam_remote_app_so_godawful_terrible/).

Here's a list of common compliants:

- The app needs 'all the time' location permissions to work
- Confusing
- Somtimes doesn't work
- Unresponsive janky UI

Fuji tried to solve these problems with their new app, called '[Xapp](https://play.google.com/store/apps/details?id=com.fujifilm.xapp&hl=en_US)'. This
new app looks more modern and is more responsive, but still receives complaints:

- Buggy, sometimes doesn't work
- Some functionality still requires 'all the time' location permissions
- Only supports a small selection of Fuji's newest cameras
- Minor grievance: Xapp apk is 200mb and requires Android 11+

*Side note: 'all the time' approximate location permissions in Android are [required](https://developer.android.com/develop/connectivity/wifi/wifi-scan#wifi-scan-permissions) for scanning wireless access points or bluetooth devices.*

Most Fuji customers still have to use the old 'Camera Remote' app. This includes me, as I own an X-A2 and X-H1.

So, [one year ago](https://github.com/petabyt/fudge/commit/b282b6a8ff5f88c51e1b72333d447b71077545ea), I got to work on a new app to see if I
could do better than Fujifilm and fix any of these pain points.

## The PTP Protocol
To transfer photos, run a liveview, and alter camera settings, Fuji cameras expose a WiFi access point with a PTP/IP server running at `192.168.0.1`.
I had previously written my own [PTP library](https://github.com/petabyt/camlib), so I had a great starting point already.

Fujifilm actually offers a [developer SDK](https://fujifilm-x.com/global/special/camera-control-sdk/), which supports PTP and PTP/IP.
Other than binaries only being offered on x86_64 MacOS and Windows, it only supports a small range of Fuji's latest cameras (15 to be exact).
The SDK also hot a lot of [heat](https://news.ycombinator.com/item?id=30792661) for voiding warranties, so I felt it's probably best to avoid it altogether.

Within a few days, I was able to get a basic Android PoC working on my X-A2:

![fujiapp screenshot](https://danielc.dev/images/Fy2atQiWcAEyBm6.jpg)
![fujiapp screenshot 2](https://danielc.dev/images/Fy2atb6WcAQzGSk.jpg)

The trickiest part here is the setup process. Once connected to the access point, you connect to a PTP/IP server on port `55740`.
Communication starts with a typical REQ/ACK, after that the client runs a `PtpOpenSession` command. Everything that follows is Fuji's proprietary setup:

For connecting to older Fuji cameras to download photos:

- After REQ/ACK, user sees the client's name on camera screen, must press OK to continue
- Check Fuji's EventsList for it to report that the camera is not locked
- Set a few version properties
- Start downloading thumbnails/photos with mostly standard PTP operations

Fuji also has a "MULTIPLE TRANSFER" mode (at least on older cameras), where the camera will only allow the client to download a few select photos.
This is the process of downloading those photos that follows the previously mentioned setup process:

- Get PtpObjectInfo for object ID 1
- Download file with PtpGetPartialObject with max 0x100000 (can't be any other number)
- Once the entire file is downloaded, the camera will swap object ID 1 with the next in the list
- If we are at the end of the list, camera will kill communication
- Repeat loop

*Note: In PTP, 'objects' are images/files/folders, and `PtpObjectInfo` is a structure describing an object.*

In later cameras, Fuji added what I call 'remote mode'. Entering remote mode (and setting up liveview/event sockets) seems to be necessary to continue with
doing anything else (downloading thumbnails/photos). This mode has a more tricky setup process:

- Check `EventsList`, check that the camera state allows remote mode
- Set a few version properties
- Set client mode to remote mode
- (The camera will not respond to the previous request until the user presses 'OK')
- Setup remote version properties
- Run `PtpOpenCapture` - this tells the camera to open a MJPEG liveview socket and an event socket
- Client must establish a connection to both sockets
- Run `PtpTerminateOpenCapture`
- Set version properties for the image downloading behavior
- Set the camera's mode to 'remote image viewer'
- Start downloading thumbnails/photos

Overall, Fuji's PTP/IP has several notable client modes:

- "MULTIPLE TRANSFER" mode
- Image viewing mode (old)
- GPS/geolocation mode
- Remote mode (liveview) and old remote mode
- Remote photo viewing mode
- A few modes for Xapp/bluetooth handoff, which I haven't looked into yet
- Error mode - just to show an error message on the camera's screen

I recommend checking out [`lib/fuji.c`](https://github.com/petabyt/fudge/blob/master/lib/fuji.c) which describes how most of these modes are setup or how they work.

*To be specific Fuji uses a non-standard version of PTP/IP where they send/receive ISO-compliant PTP/IP REQ/ACK packets,
but use USB-style PTP packets for everything else. They simply forked their MTP codebase and made it work over TCP.*

## vcam
Understanding Fuji's protocols by disassembling their app seems... pretty lame. So I needed a better way to help develop Fudge
that would help speed up development.

[vcam](https://github.com/petabyt/vcam) is a complete reimplementation of Fuji's PTP wireless backend
(and Canon too). With a modern WiFi card, it can perfectly emulate a Fuji WiFi access point that is indistinguishable from the one that a real camera would expose.
Thus, I can spoof Fuji's own software and try and match the behavior of my app with theirs.

![Fujis Camera Remote connected to a vcam server running on my laptop](https://danielc.dev/images/Screenshot_20240402-140041.png)  

It also helps a ton with testing Fudge since I don't need to keep resetting a real camera (and keep it charged) when testing and debugging.

## Code
Also I thought briefly going over the codebase might be interesting?

- Fudge currently only supports Android. There's code for a CLI/desktop app, but this was mainly written for CI.
- Fudge is mostly C. TCP and USB-OTG communication is done through `read`/`write`/`ioctl`, with some Java glue to set things up. This makes it fairly fast compared to Java alone, and portable.
- The frontend is Java and native activities.
- Lua is included, as well as UI and PTP bindings.

Fudge also includes a [libui](https://github.com/libui-ng/libui-ng)-compatible UI library: [libuifw](https://github.com/petabyt/libuifw)    
This is to allow C/C++ or Lua code to create/alter UI. As a side effect, the same code can be run on Windows/Linux/MacOS (and eventually iOS)

## Roadmap
### Liveview
I'm slowly working on implementing a liveview with libjpeg-turbo, with the ability to change common camera settings.
![horizontal fudge liveview](https://danielc.dev/images/Screenshot_20240609-224515.png)

### iOS
Surprise! Fudge works on iOS!

![png](https://danielc.dev/images/IMG_0003.PNG)

Okay, it's barely working and doesn't have a UI, but it's a decent PoC. I don't know if I have the time to finish an iOS port, but at least I had the chance to try Objective-C for the first time :)

### Bluetooth
[SimpleBLE](https://github.com/OpenBluetoothToolbox/SimpleBLE) looks like a good option as a cross-platform BLE library, at least when their [Android port](https://github.com/OpenBluetoothToolbox/SimpleBLE/tree/feature/android) is finished.

### PC AUTO SAVE
'PC AUTO SAVE' is a long-standing Fuji feature (2014-2022) where a Fuji camera and [Fujifilm's software](https://fujifilm-dsc.com/en/pc_autosave/download.html) connect to a WiFi network,
the software discovers the camera over SSDP and can then download raws, jpegs, and mov files over PTP. This functionality can easily be implemented in Fudge.

### USB
Over OTG, Fudge can replace the functionality of Fuji desktop apps:

- X RAW Studio (alter RAW photos)
- Remote shoot (X Acquire, Webcam utility) 

I don't know anybody who carrys around the cables needed to connect an Android phone to a camera, but it might be a useful feature.

## Conclusion
Fudge continues to be an active project. I'm interested in seeing if I can do do better than Fujifilm, without documentation,
an SDK, or development team, in my free time. Just me, some tcpdumps, and a whole bunch of C.

[Fudge on Github](https://github.com/petabyt/fudge)
