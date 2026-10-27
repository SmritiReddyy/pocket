<p align="center">
  <img src="Support/AppIcon-1024.png" width="112" alt="Peekaboo icon">
</p>

<h1 align="center">Peekaboo</h1>

<p align="center"><b>Now you see it, now you don't. 👀</b></p>

---

My MacBook's notch just sat there. Now it plays peekaboo: it pops open when something's
happening and hides when nothing is. Think iPhone Dynamic Island, but for my Mac.

**Click the notch** and you get:

- 📝 a **scratchpad** you can type into right there
- ✅ today's **reminders**, ready to tick off
- 📋 your last few **copies**, one click to copy again
- 📅 your next **event** and ⏱️ one-tap **timers** and Focus sessions

**Click it again** and it hides. Boo.

It also quietly handles charging, low battery, AirPods, volume and brightness, finished
downloads, a file tray, AirDrop, a camera mirror, Keep Awake and CPU/memory stats.

No account, no tracking, never phones home. 🔒

## Get it running

You'll need macOS 14+ and Apple's developer tools (`xcode-select --install`). Then:

```bash
Scripts/build-app.sh
```

Drag `build/Peekaboo.app` into Applications, open it, and you're in.

👉 **[How to use it](docs/HOW-TO-USE.md)** — every click, swipe and shortcut.

## Credit where it's due

Built on [Dynamic Notch](https://github.com/shandilyaswagat/dynamic_notch) by Swagat Shandilya.
I stripped out music and calls, made a second click close the notch and packed more onto Home.
