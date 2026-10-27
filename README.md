<p align="center">
  <img src="Support/AppIcon-1024.png" width="112" alt="Pocket icon">
</p>

<h1 align="center">Pocket</h1>

<p align="center"><b>A little pocket at the top of my Mac. 👖</b></p>

---

My MacBook's notch just sat there. Now it's a pocket: it pops open when something's happening
and tucks away when nothing is. Think iPhone Dynamic Island, but for my Mac.

**Click the notch** and reach in for:

- 📝 a **scratchpad** you can type into right there
- ✅ today's **reminders**, ready to tick off
- 📋 your last few **copies**, one click to copy again
- 📅 your next **event** and ⏱️ one-tap **timers** and Focus sessions

**Click it again** and it zips shut.

It also quietly handles charging, low battery, AirPods, volume and brightness, finished
downloads, a file tray, AirDrop, a camera mirror, Keep Awake and CPU/memory stats.

No account, no tracking, never phones home. 🔒

## Get it running

You'll need macOS 14+ and Apple's developer tools (`xcode-select --install`). Then:

```bash
Scripts/build-app.sh
```

Drag `build/Pocket.app` into Applications, open it, and you're in.

👉 **[How to use it](docs/HOW-TO-USE.md)** — every click, swipe and shortcut.

## Credit where it's due

Built on [Dynamic Notch](https://github.com/shandilyaswagat/dynamic_notch) by Swagat Shandilya.
I stripped out music and calls, made a second click close the notch and packed more onto Home.
