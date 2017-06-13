# **A**ndroid **S**emiautomated **CE**lullar **N**etwork **T**esting

### Why?

Ascent is designed to encourage E2E tests for R&D cellular networks (2/3/4G) by simplifying the process of testing fundamental functionalities (CS/PS) such as making a call, sending a SMS and verify data connectivity (UP/DL) with 2 Android devices as subscribers (MS/UE).

### Why Android?

Android phones are cheap subscribers (~ 40 €). Furthermore, they're shipped with 2G, 3G and 4G capabilities. Thus enabling us to test all these cellular network types with same devices.

### Why semiautomated?

v0.2: Automation incoming! Every test will be verified and its result gets printed. The old (v0.1) call() function remains as icall() (interactive call).

v0.1: Because ascent will only execute tests, but *you* still have to verify them by (hopefully only) observing and listening to them. There shouldn't be any need to go afk in order to physically interact with the Android devices.
<br>

### Okay, but how does the test flow look like?

Please click on the preview image to watch demo (~31 MB).

<a href="https://boddenberg.it/ascent/final_ascent_v0.2.mp4" target="_blank"><img src="https://boddenberg.it/ascent/preview.png"
alt="ascent demo"/></a>


### Nice, what do I need to get started?

I want to point out again that ascent is designed to test R&D cellular network setups, e.g. [Osmocom](https://osmocom.org/) based ones. There is probably not much use in testing commercial cellular networks (MNOs) with ascent. Although MNOs will probably appreciate tests, where testers pay for their services.

In order to run ascent two Android (tested on 4.4, 5.1, 6.0, 7.1) devices with the following configurations are necessary:

* activate "developer options"
* enable "stay awake" in "developer options"
* install [SMS Messaging (AOSP)](https://play.google.com/store/apps/details?id=fr.slvn.mms) as default SMS app
* disable any password/pattern to unlock            (swiping should unlock your phone)
* no root required

*Notes:*
* Some devices might need to be rooted to support verifying data connectivity!
* Keep in mind that ascent gets flaky the more notifications/UI-interruptions appear.

Furthermore an adb daemon must be installed on your machine. In case one doesn't have adb already installed - no panic! One can install it via [android-tools-adb](https://packages.debian.org/jessie/android-tools-adb) debian package (also available for ARM, MIPS,...). Furthermore Google also provides [SDK Platform Tools](https://developer.android.com/studio/releases/platform-tools.html) for Linux, Windows and MacOS environments, so there's no need to download and install a fully-blown Android SDK.

After both adb connections have been successfully established (RSA handshake), you need to clone ascent repo and change ascent.cfg to suite your setup. Just have a look at the default one to be able to apply mentioned changes or - for more information - read `./ascent -h`.
<br>

## Alright, Let's test!

```
./ascent 3g
```
![console output of './ascent 3g'](https://boddenberg.it/ascent/ascent_3g.png)

The following test cases and suites are available:

* `./ascent.sh sms`
* `./ascent.sh call`
* `./ascent.sh data`
* `/ascent.sh 2g`&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;(combines sms + call)
* `/ascent.sh 3g`&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;(combines sms + call + data)

*Note: One can also pass config file:* `./ascent.sh -c 2g.cfg sms`

## Interactive mode

Yes, ascent provides an interactive mode! Simply source ascent to activate it.

```
source ascent.sh
```
![console output of 'source ascent.sh'](https://boddenberg.it/ascent/source_ascent.png)

*Note: One can also pass config file:* `source ascent.sh -c /ascent_config/ascent.cfg`

In **interactive mode** one can use above mentioned test cases and suites as well as some more granular test cases like:

```
call d0 d1
```
![console output of 'call d0 d1'](https://boddenberg.it/ascent/call_d0_d1.png)

```
sms d1 d0
```
![console output of 'sms d0 d1'](https://boddenberg.it/ascent/sms_d1_d0.png)

```
aping d0 heisec.de 5
```
![console output of 'ping d1 heisec.de 5'](https://boddenberg.it/ascent/aping_d0_heisec_5.png)

Furthermore functions are available to reset, unlock and debug phones via adb commands in case of a test failure:

* `help`              
* `sanity`
* `go_to_homescreen`
* `unlock_device (d0|d1)`
* `(adb0|adb1) shell ...`

*Note: Auto-completion for ascent commands is available in interactive mode.*

### What's next?

The further development of ascent will probably be limited to bug fixes and handy interactive helpers, because using adb to intent a call or sms can be quite flaky in fact of running as an UI Thread. That's why I rather consider spending time on an native Android application, which will do above stated in the background (thus independent from current UI Thread) than on improving ascent. Especially since an native Android application seems to allow more fine grained test verification on devices itself e.g. SMS status report as pendingIntent, quering network_connection_type, signal strength,...

### Hey, I've found a bug!

Great! Please send a mail holding a *detailed bug report* to ascent@boddenberg.it
