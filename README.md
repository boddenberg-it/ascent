# **A**ndroid **S**emiautomated **CE**lullar **N**etwork **T**esting

### Why?

Ascent is designed to encourage E2E tests for R&D cellular networks by simplifying
the process of testing fundamental functionalities (CS/PS) such as making a call,
sending a SMS and verify data connectivity (UP/DL) with 2 Android devices as subscribers (MS/UE).

### Why semiautomated?

Because ascent will only execute tests, but you still have to verify them by
(hopefully only) observing and listening to them. There shouldn't be any need to go afk in order to physically interact with the Android devices.

### Okay, but how does the test flow look like?

Please click on the preview image to watch a short demo (~12 MB).

<a href="https://github.boddenberg.it/ascent/ascent_demo.mp4" target="_blank"><img src="https://github.boddenberg.it/ascent/ascent_video_preview.jpg"
alt="demo (low quality)"/></a>

<a href="https://github.boddenberg.it/ascent/ascent_demo_full_qualitiy.mp4" target="_blank"><i>demo (full quality ~171 MB)</i></a>

### Nice, what do I need to get started?

In order to run ascent two Android devices with the following configurations are necessary:

* activate "developer options"
* enable "stay awake" in "developer options"
* install [SMS Messaging (AOSP)](https://play.google.com/store/apps/details?id=fr.slvn.mms) as default SMS app   (only a suggestion)
* disable any password/pattern to unlock            (swiping should unlock your phone)
* no root required

*Note: Only my S3 doesn't allow to execute ping as non-root user. Some devices might
need to be rooted to support verifying data connectivity!*

Furthermore an adb daemon must be available on your machine. In case one doesn't have adb already installed - no panic! One can install it via [android-tools-adb debian package](https://packages.debian.org/jessie/android-tools-adb). Furthermore Google also provides [SDK Platform Tools](https://developer.android.com/studio/releases/platform-tools.html) for Linux, Windows and MacOS environments, so there's no need to download and install a fully-blown [Android SDK](https://developer.android.com/studio/index.html).

After both adb connections have been successfully established (RSA handshake), one need to simply clone ascent repo and change ascent.cfg to suite your setup. Just have a look at the default one to be able to apply mentioned changes or - for more information - read `./ascent -h`.

## Alright, Let's test!

![console output of 'source ascent.sh'](http://github.boddenberg.it/ascent/ascent_3g_call_example.jpg)

The following test cases and suites are available:

* `./ascent.sh sms`
* `./ascent.sh call`
* `./ascent.sh data`
* `/ascent.sh 2g`&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;(combines sms + call)
* `/ascent.sh 3g`&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;(combines sms + call + data)

## Interactive mode

Yes, ascent provides an interactive mode. Simply source ascent to activate it.

```
source ascent.sh
```
![console output of 'source ascent.sh'](http://github.boddenberg.it/ascent/ascent_source_example.jpg)

*Note: One can also pass config file:*

`source ascent.sh -c /ascent_config/ascent.cfg`

In **interactive mode** one can use above mentioned test cases and suites as well as some more granular test cases like:

```
call d1 d0
```
![console output of 'call d1 d0'](https://github.boddenberg.it/ascent/ascent_call_example.jpg)

```
sms d1 d0
```
![console output of 'sms d0 d1'](https://github.boddenberg.it/ascent/ascent_sms_example.jpg)

```
ping d0 heisec.de
```
![console output of 'ping d1 heisec.de'](http://github.boddenberg.it/ascent/ascent_ping_example.jpg)

Furthermore functions are available to reset, unlock and debug phones via adb commands in case of a test failure:

* `help`              
* `sanity`
* `go_to_homescreen`
* `unlock_device (d0|d1)`
* `(adb0|adb1) shell ...`

*Note: Auto-completion for ascent commands is available in interactive mode.*

### What's next?

The further development of ascent will probably be limited to bug fixes, because using
adb to intent a call, sms and there like can be quite flaky in fact of running as
an UI Thread. That's why I rather consider spending time on an native Android application,
which will do above stated in the background (thus independent from current UI Thread)
than on improving ascent. Especially since an native Android application seems to allow
test verification on devices itself e.g. SMS status report as pendingIntent, quering
network_connection_type, signal strength,...

### Hey, I've found a bug!

Great! Please send a mail holding a *detailed bug report* to ascentREMOVETHIS@boddenberg.it
