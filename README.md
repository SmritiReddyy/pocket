<p align="center">
  <img src="Support/AppIcon-1024.png" width="112" alt="Dynamic Notch icon">
</p>

<h1 align="center">Dynamic Notch</h1>

<p align="center"><b>My MacBook's notch, finally pulling its weight.</b></p>

---

The notch just sat there. Now it's a tiny command centre: it pops open when something's
happening and disappears when nothing is. Think iPhone Dynamic Island, but for my Mac (and with
zero music stuff, because I didn't want it).

**Click the notch** and you get:

- 📝 a **scratchpad** you can type into right there
- ✅ today's **reminders**, ready to tick off
- 📋 your last few **copies**, one click to copy again
- 📅 your next **event** and ⏱️ one-tap **timers** and Focus sessions

**Click it again** and it tucks away.

It also quietly handles calls, charging, low battery, AirPods, volume and brightness, finished
downloads, a file tray, AirDrop, a camera mirror, Keep Awake and CPU/memory stats.

No account, no tracking, never phones home. 🔒

## Get it running

You'll need macOS 14+ and Apple's developer tools (`xcode-select --install`). Then:

```bash
Scripts/build-app.sh
```

Drag `build/Dynamic Notch.app` into Applications, open it, and you're in.

👉 **[How to use it](docs/HOW-TO-USE.md)** — every click, swipe and shortcut.

## Credit where it's due

Built on [Dynamic Notch](https://github.com/shandilyaswagat/dynamic_notch) by Swagat Shandilya.
I stripped out music, made a second click close the notch and packed more onto Home.
