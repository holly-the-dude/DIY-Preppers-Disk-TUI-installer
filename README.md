# DIY Prepper Disk — TUI Installer

**An unofficial, menu-driven Bash installer for building a personal, offline knowledge and preparedness library on a Raspberry Pi.**

The single-file installer, [`install-diy-prepperdisk-tui.sh`](install-diy-prepperdisk-tui.sh), uses [Internet-in-a-Box (IIAB)](https://internet-in-a-box.org/) as its foundation and brings together Kiwix archives, maps, educational resources, emergency manuals, and local browser tools. It supports both a terminal user interface (TUI) and automation-friendly command-line subcommands.

> **Project status:** Experimental / community DIY project. The Bash syntax and help output have been checked, but a complete installation has **not** been validated on Raspberry Pi hardware. Upstream archive names, IIAB roles, and download URLs can change. Test the installation and its offline content before relying on it.
>
> **Not affiliated with or endorsed by Prepper Disk, Internet-in-a-Box, Kiwix, or Library-Creator.** This project does not include Prepper Disk's proprietary or separately licensed media.

## Inspiration, credit, and why this project exists

This project is **based on the general DIY approach and resource list described in [Prepper Disk's DIY Prepper Disk Advanced guide](https://www.prepperdisk.com/pages/diy-prepper-disk-adv)**. That page identifies the important building blocks—Raspberry Pi, Internet-in-a-Box, Kiwix, and freely available offline educational and preparedness content.

### Prepper Disk's DIY invitation — and what this installer adds

Prepper Disk deserves credit for **openly encouraging people to build their own offline library**. Its [DIY Prepper Disk Advanced guide](https://www.prepperdisk.com/pages/diy-prepper-disk-adv) describes a free beginner build plan, identifies Raspberry Pi, Internet-in-a-Box (IIAB), Kiwix, and download sources, and states that no purchase is required. A Prepper Disk Facebook advertisement shared with this project goes further, saying **“WE'RE GIVING AWAY HOW TO BUILD YOUR OWN PREPPER DISK”** and inviting readers to use its shopping list, download links, and step-by-step instructions.

The ad also makes a conventional, understandable sales pitch: the commercial product is preassembled, comes with its library preloaded, includes support, and may qualify for a warranty. Buyers in the shared Facebook discussion describe convenience and saved time as reasons to purchase it. **It would be inaccurate to conclude from this material that the company is trying to prevent DIY builds.** Both a DIY route and a ready-made product can serve different people.

**The gap this project addresses is reproducibility and automation, not secrecy.** Even when a vendor shares a plan, pulling together OS setup, compatible services, hundreds of gigabytes of content, storage layout, offline networking, and recovery can still be difficult. This independent installer aims to make more of that process repeatable with a single auditable Bash file, a TUI, and honest notes about steps the script cannot perform automatically. It does **not** reproduce Prepper Disk's proprietary curation, licensed materials, customer support, or warranty.

IIAB itself deserves special acknowledgment for its longstanding work making local, offline knowledge accessible in remote and underserved communities. This project builds on that open-source foundation rather than replacing it.

### A well-documented open alternative: Library-Creator

For another open and **well-documented** approach, see **[Library-Creator](https://github.com/holly-the-dude/Library-Creator)**. Its public repository contains a project README, separate **installation**, **usage**, and **development** guides, a bootstrap reference, and individual documentation for services such as maps, Wikipedia, music, and Meshtastic. Its architecture and features differ from this IIAB-based installer; they are **separate projects**, and Library-Creator is not installed by this script.

The URL [github.com/library-creator](https://github.com/library-creator) was also suggested as a reference, but **that GitHub profile currently does not show public repositories**. The working, documented repository verified for this README is **[github.com/holly-the-dude/Library-Creator](https://github.com/holly-the-dude/Library-Creator)**.

### Another community example: a personal research library

A contributor in the shared Facebook discussion describes using IIAB's existing web server to expose a separate, personally curated research collection from a USB drive. Their published [DFranke84/Research](https://github.com/DFranke84/Research) repository contains a PC-based **Research Library** manager and documentation for a browser-accessible viewer. It is a useful reference for custom content, local search, and serving personal documents through an existing offline server. **This is an independent project and is not installed or bundled by this script.** Review its license and requirements before borrowing code or ideas.

## Features and current implementation

| Feature | What the script actually does | Additional work or limitations |
| --- | --- | --- |
| TUI installer | `whiptail` / `dialog` menus with numbered text-menu fallback | Interactive terminal required |
| IIAB | Downloads and launches the **official IIAB installer** | May require reboot and `sudo iiab` continuation |
| Kiwix offline articles | Attempts to download current matching ZIM archives | Availability and archive naming may change |
| Wikipedia and medical references | Profile-based English Wikipedia plus medical archive | Full Wikipedia can be very large |
| Repair and how-to archives | Attempts iFixit and Appropedia; adds wikiHow in larger profiles | Individual archive availability is not guaranteed |
| Books and educational video archives | Tries Gutenberg, Wikibooks, TED and selected other collections in larger profiles | Only downloads matching, available, legally hosted ZIMs |
| Maps | Configures IIAB's built-in maps service | **Choose/download detailed map regions separately** |
| Kolibri | Configures the IIAB Kolibri service | **Select/download courses separately** |
| Emergency PDF manuals | Attempts several specific government PDF downloads | Source URLs can move or disappear |
| Custom offline portal | Creates pages for the library, manuals, videos and tools | Depends on the IIAB web server routing working |
| Morse tool | Browser-based text-to-Morse, audible playback, and typed Morse-to-text | **Not** a microphone, RF, or live-audio decoder |
| Emergency phrasebook | Static English–Spanish emergency phrases | Not an adaptive translator |
| Argos Translate | Optionally installs a local English–Spanish translation service | Dependencies/models may fail on ARM or low-memory Pi hardware |
| PDF and video import | Copies supported files from a local directory | **Top-level files only**, not recursive; doesn't overwrite names |
| USB library | Attempts to enable IIAB USB support | Mounting and file-system support may require setup |
| Separate OS/SD and removable USB content | **Not yet implemented** as a managed storage layout | See proposed recovery-friendly architecture below |
| Clone and restore tooling | **Not implemented** | Needs explicit disk selection, verification, and safe restore procedures |
| Wi-Fi hotspot | Calls IIAB's `iiab-hotspot-on` helper, if present | Can disconnect Wi-Fi SSH; configure over Ethernet |
| Status and operations log | Reports paths, service state and download operations | Not a full transcript of every installer command |

### What's intentionally **not** included

- Prepper Disk-exclusive books, licensed survival media, proprietary branding/interface, or its curated *Urgent Answers* collection.
- RepeaterBook's proprietary database or bulk-extracted records; use its official supported applications instead.
- Automatically downloaded Kolibri courses, satellite-image regions, or a complete library of National Park maps.
- Arbitrary YouTube downloads or unlicensed book/media redistribution.
- Disk imaging, SD-card formatting, partitioning, automatic storage relocation, USB cloning, or automatic router port forwarding.

Public availability **does not necessarily mean public domain**. Review the source's terms and licenses before storing, copying, or sharing content.

## Requirements

- **Raspberry Pi 4 or 5** (recommended), with **Raspberry Pi OS Lite, 64-bit** (`aarch64`).
- A reliable power supply and a microSD card or compatible attached storage with adequate free space. A separate USB SSD is a good future layout for large content collections, but **the current script does not automatically relocate IIAB data to it**.
- **Ethernet and internet access** for initial installation and content downloads (strongly recommended for initial configuration).
- A normal Raspberry Pi user account with `sudo` privileges and an interactive terminal (local console or SSH with TTY).
- `curl`, Python 3, and other packages installed by the bootstrap script or operating system.
- Optional: `whiptail` for an easier checkbox/radio-button UI; `dialog` is also supported. Without either, use the numbered text menu.

**Storage guidance:** The *Starter* profile is the smallest. *Balanced* downloads a more extensive library. *Full* may consume **hundreds of GB**; **512 GB or larger** is a sensible starting point, but check the actual archives and leave room for future updates. No profile guarantees a fixed size because publisher files change.

## Quick start

### 1. Install Raspberry Pi OS

Flash **Raspberry Pi OS Lite (64-bit)** with [Raspberry Pi Imager](https://www.raspberrypi.com/software/). Enable SSH and set the username/password if appropriate. The OS imaging process **does erase the selected destination**, so verify your card or drive before clicking *Write*.

Boot the Pi and connect it by **Ethernet** if possible.

### 2. Copy the installer to the Pi

Put `install-diy-prepperdisk-tui.sh` in your home directory, then run:

```bash
sudo apt-get update
sudo apt-get install -y whiptail
chmod +x install-diy-prepperdisk-tui.sh
./install-diy-prepperdisk-tui.sh
```

Launch as your **normal user**, not with `sudo`. The TUI requests `sudo` when an operation needs administrative access. Its IIAB bootstrap runs under your regular account as intended by the upstream installer.

### 3. Install Internet-in-a-Box first

In the TUI choose **`1 — Install initial Internet-in-a-Box`** and follow the upstream prompts. Installation can reboot or stop for a manual continuation. Follow the prompts and, if instructed, run:

```bash
sudo iiab
```

Finish IIAB completely **before** running the other component installers.

### 4. Select a profile and install components

Restart the menu:

```bash
./install-diy-prepperdisk-tui.sh
```

Choose **`2 — Choose content profile`**, then **`3 — Guided complete setup`** or **`4 — Choose individual components`**. *Balanced* is a reasonable first attempt on large storage; *Starter* is a safer smoke test. The checkbox workflow lets you leave the heavier Argos translator disabled.

> **Important:** Guided setup attempts several independent operations and reports errors, but a later successful step does **not** prove that all previous operations succeeded. Review the output and the status menu.

### 5. Finish content selection and test offline

While internet is still working:

1. Open the IIAB admin console at **`http://box.lan/admin`** and import the **Kolibri courses** you want.
2. Open **`http://box.lan/maps/`** and download the **high-resolution map regions** relevant to you.
3. Confirm that downloaded ZIM archives appear in Kiwix; add any missing content through IIAB's content tools.
4. Test the local landing page at **`http://box.lan/prepperdisk/`**. Address availability depends on your IIAB networking and DNS configuration.
5. **Disconnect the internet** and verify that your actual reference material, maps, courses, and browser tools still work on a phone or laptop connected to the Pi.

The local Pi provides previously downloaded information; **it does not provide live internet**.

## TUI menu reference

| Menu choice | Action |
| --- | --- |
| `1` | Launch the official initial Internet-in-a-Box installer |
| `2` | Pick **Starter**, **Balanced**, or **Full** profile |
| `3` | Attempt complete guided setup for selected profile |
| `4` | Select individual components using checkboxes |
| `5` | Import existing PDF or video files from a Pi-accessible directory |
| `6` | Download an individual Kiwix ZIM by direct HTTPS URL |
| `7` | Enable Wi-Fi hotspot (requires IIAB helper; Ethernet advised) |
| `8` | View installed services, storage and local content status |
| `9` | Read the script's operations log |
| `10` | Display help and remaining manual setup notes |
| `Q` | Quit |

Canceling a dialog should return to the menu without starting that selected action. The script also presents preflight warnings and confirmation dialogs before larger changes.

## Command-line / SSH automation

All of the following commands operate on **`install-diy-prepperdisk-tui.sh`**. For detailed built-in help:

```bash
bash install-diy-prepperdisk-tui.sh help
```

| Task | Command |
| --- | --- |
| Launch menu | `bash install-diy-prepperdisk-tui.sh` |
| Start upstream IIAB installer **as normal user** | `bash install-diy-prepperdisk-tui.sh install` |
| Guided setup (Starter) | `sudo bash install-diy-prepperdisk-tui.sh all starter` |
| Guided setup (Balanced) | `sudo bash install-diy-prepperdisk-tui.sh all balanced` |
| Guided setup (Full; confirmation required) | `sudo bash install-diy-prepperdisk-tui.sh all full` |
| Install/configure IIAB services | `sudo bash install-diy-prepperdisk-tui.sh services balanced` |
| Download Kiwix archives | `sudo bash install-diy-prepperdisk-tui.sh content balanced` |
| Download public emergency PDFs | `sudo bash install-diy-prepperdisk-tui.sh manuals` |
| Rebuild the local web landing page | `sudo bash install-diy-prepperdisk-tui.sh portal` |
| Attempt Argos models/service | `sudo bash install-diy-prepperdisk-tui.sh translator en es` |
| Import a PDF folder | `sudo bash install-diy-prepperdisk-tui.sh add-pdfs /media/pi/USB/manuals` |
| Import a video folder | `sudo bash install-diy-prepperdisk-tui.sh add-videos /media/pi/USB/videos` |
| Download one `.zim` | `sudo bash install-diy-prepperdisk-tui.sh add-zim https://example.org/path/example.zim` |
| Enable hotspot | `sudo bash install-diy-prepperdisk-tui.sh hotspot` |
| View status | `bash install-diy-prepperdisk-tui.sh status` |

The example `add-zim` URL is a **placeholder**, not a real archive. Use a valid direct HTTPS `.zim` URL from the [Kiwix catalog](https://library.kiwix.org/) or [download directory](https://download.kiwix.org/zim/). This subcommand does not accept arbitrary web pages, query parameters, or non-HTTPS URLs.

### Profiles

- **Starter:** Smaller English Wikipedia top-articles archive; medical, iFixit, and Appropedia archives are attempted.
- **Balanced:** Complete English Wikipedia *without pictures*, medical and repair archives, plus wikiHow, Gutenberg, Wikibooks, and selected TED topic archives.
- **Full:** Complete English Wikipedia *with pictures* and additional Wikisource, Stack Exchange, and TED topic archives. Substantially more storage and bandwidth may be required.

Archive selection scans a publisher directory for matching dated filenames. **If a category is missing, the installer prints a warning instead of silently claiming to have downloaded it.** Names and availability can change independently of the script.

## Files, ports, and configuration

| Path or address | Purpose |
| --- | --- |
| `/etc/iiab/local_vars.yml` | IIAB settings; script makes timestamped backups when the file exists |
| `/library/zims/content/` | Kiwix ZIM download destination |
| `/library/www/html/prepperdisk/` | Custom portal and local browser tools |
| `/library/www/html/prepperdisk/manuals/` | Downloaded/imported PDFs |
| `/library/www/html/prepperdisk/videos/` | Imported videos |
| `/opt/prepperdisk/` | Optional Argos translator installation |
| `/var/lib/prepperdisk/operations.log` | Script's operation and download log |
| `http://box.lan/prepperdisk/` | Offline home page (when IIAB DNS/routing is working) |
| `http://box.lan:8765/` | Optional offline translator, **no authentication** |

**Security:** The optional translator binds to network interfaces on **port 8765** and is not authenticated. Keep it on a trusted offline/local network only: **do not port-forward or expose it to the public internet**. Set appropriate passwords on the IIAB admin console, keep the system updated, and verify what network services are enabled.

## Recommended next improvement: separate the system from the data

The Facebook discussion raised a particularly useful design suggestion: **keep Raspberry Pi OS and applications on the microSD card, and store the offline library on a removable USB SSD or flash drive**. If the Pi or its boot card fails, this separation can make it easier to rebuild the system without redownloading a very large library.

A recovery-friendly target layout would look like this:

```text
microSD card (boot/system)             external USB SSD (content)
├── Raspberry Pi OS                    ├── Kiwix .zim archives
├── IIAB and other applications        ├── offline maps and Kolibri content
├── this installer and configuration  ├── PDF manuals, books, videos
└── network and service settings       └── personal research documents
```

The recommended implementation would mount the external drive at a **stable path** (potentially `/library`, after validating compatibility with the installed IIAB release), identify it by **filesystem UUID** rather than a changing `/dev/sdX` name, and ensure services only start when their content storage is available. A replacement Pi still needs IIAB, service configuration, compatible permissions, and indexes restored or rebuilt; **moving a USB drive alone is not guaranteed to make the library instantly work on any other Pi**.

**Current behavior:** The installer currently writes its ZIMs and portal files to paths under `/library` and optionally enables IIAB's USB library feature. It does **not** partition or mount an external data drive for all services, move existing content, or configure boot-time dependencies. In particular, **“USB library support” is not the same thing as “all downloaded content lives on USB.”** Check actual mount points with `findmnt /library` and `df -h /library` before downloading large archives.

### Proposed cloning and disaster recovery features (not in v3)

1. **Back up the boot system**: create a verified Raspberry Pi OS/IIAB configuration backup or SD image, with an explicit destination and available-space check.
2. **Clone the content drive**: copy archives and personal content to a second USB drive using resumable, integrity-checked transfer; maintain a manifest of paths and checksums.
3. **Restore or rebuild**: document how to rebuild a boot card, remount the library disk by UUID, restore settings, repair permissions, and regenerate service indexes.
4. **Test the failure scenario**: disconnect the old Pi, boot a replacement using the backup, and confirm browser access to critical resources with the internet disconnected.

Cloning may **overwrite a destination drive**. A future tool must require explicit source/destination confirmation, identify mounted disks, protect the current system disk, and verify the result. **No clone or destructive disk operation is currently performed by this installer.** Keep at least one independent copy of irreplaceable personal files; a movable primary drive is not itself a backup.

## Troubleshooting

**The menu is plain text or missing:** Run `sudo apt-get install -y whiptail` and use a real terminal (`ssh -t` if needed). The numbered fallback is intentional.

**“IIAB not present” or missing `runrole`:** Complete the upstream IIAB installation, required reboots, and `sudo iiab` continuation before running `services`, `content`, or `all`.

**A ZIM archive is missing:** Browse [Kiwix's catalog](https://library.kiwix.org/) or the IIAB Admin Console. Archive directories and filename patterns sometimes change, and the script may not recognize the current release. You can import a direct `.zim` URL manually.

**PDF download failed or file is invalid:** Government agencies may rename or move PDFs. Use `add-pdfs` with a legitimately downloaded replacement and rerun `portal` as needed.

**Translator installation fails:** Argos may need platform-specific binary packages, model downloads, sufficient storage, and memory. It is optional; use `journalctl -u prepperdisk-translate` if the service exists but won't start.

**Hotspot drops SSH:** Use Ethernet or a locally attached display and keyboard. The installer warns before changing hotspot settings.

**`box.lan` doesn't resolve:** Check IIAB's Wi-Fi/DNS settings, whether the client is attached to the correct network, and whether the IIAB web server is running. Use the Pi's reachable local IP address if needed.

**See current status:**

```bash
bash install-diy-prepperdisk-tui.sh status
sudo tail -n 100 /var/lib/prepperdisk/operations.log
sudo systemctl status kolibri prepperdisk-translate --no-pager
```

The operations log is **not** a full console transcript; capture terminal output separately if you need complete failure details.

## Design principles and limitations

This is designed to be **readable, independently reproducible, and rerunnable**. It doesn't format disks or copy commercial Prepper Disk images. Downloads attempt to resume when supported by the publisher; existing finished files are not downloaded again. It backs up IIAB's `local_vars.yml` before changing settings. Because it runs system-level commands, **review the script before execution** and back up an existing Pi installation.

There are important limits:

- The script delegates much of the real service installation to current IIAB roles, which can change upstream.
- IIAB maps, Kiwix, and Kolibri can require extra configuration even when their services install successfully.
- **No guarantee is made that all selected archives are downloadable at any particular time.**
- Offline medical and emergency material may be outdated; it does not replace professional advice or real-time alerts.
- There is no hardware-tested release guarantee yet. Treat this as a technical starting point, not a certified emergency appliance.

## Upstream projects and useful references

- **Prepper Disk DIY inspiration / comparison:** https://www.prepperdisk.com/pages/diy-prepper-disk-adv
- **Library-Creator (verified, well-documented GitHub repository):** https://github.com/holly-the-dude/Library-Creator
- **Community research library / USB-hosted content idea:** https://github.com/DFranke84/Research
- **GitHub profile mentioned for Library-Creator:** https://github.com/library-creator *(currently no public repos listed)*
- **Internet-in-a-Box:** https://github.com/iiab/iiab
- **IIAB installation guide:** https://github.com/iiab/iiab/wiki/IIAB-Installation
- **Kiwix:** https://www.kiwix.org/
- **Kiwix archive library:** https://library.kiwix.org/
- **Kolibri / Learning Equality:** https://learningequality.org/kolibri/
- **Argos Translate:** https://github.com/argosopentech/argos-translate
- **Ready.gov:** https://www.ready.gov/

---

**The point is self-reliance and choice:** Prepper Disk openly offers a DIY path alongside its ready-made product. This independent project aims to make the DIY route easier to reproduce, customize, maintain, and eventually back up or migrate—while respecting licensing and recognizing the value of professional assembly and support.
