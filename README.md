# device/onyx/Go7ml: Boox Go 7 on the mainline-based 6.18 kernel

LineageOS 24 (Android 17) for the Onyx Boox Go 7 on our 6.18 kernel (ACK `android17-6.18` +
`kernel/mainline/patches`) with an open userspace modelled on AOSP's `device/linaro/dragonboard`
(db845c / linaro_swr). The Onyx-kernel port with the QTI vendor blobs is `device/onyx/Go7`; this tree
shares its overlays (copied) and the `hardware/onyx` repos (e-ink QS tile, frontlightd).

**Status: draft, never built or booted** (written offline on 2026-11-02, before the mainline kernel has
booted on the device). Plan and reasoning: `kernel/mainline/android-mainline.md` in the port's work tree.

## What it does differently from device/onyx/Go7

| Area | Go7 (Onyx 4.19) | Go7ml (6.18) |
|---|---|---|
| Kernel | prebuilt stock | built from source, `TARGET_KERNEL_CONFIG` = `gki_defconfig` + go7 fragments |
| DTB / DTBO | stock | ours (exactly one DTB) / `prebuilts/dtbo-zero.img` (zeroed: ABL uses the DTB as-is) |
| Composer | QTI composer + `libeink_shim` | stock drm_hwcomposer on the onyx-epd card (found at boot); refresh policy in the kernel driver |
| GPU | Adreno blobs | Mesa freedreno (GLES) and turnip (Vulkan), prebuilt in `vendor/onyx/mesa` |
| Gralloc | QTI | minigbm |
| Wi-Fi / BT | qcacld / QTI BT | ath10k-snoc + wpa_supplicant (no vendor Wi-Fi HAL) / Linux HCI HAL |
| Keystore | QSEE KeyMint | non-secure KeyMint + Gatekeeper (no hardware-backed keys) |
| Health | QTI | AOSP example + Lineage charge limits on `pm7250b-charger` |
| Audio | QTI HAL | none yet (internal audio is groundwork only) |
| Filesystems | ext4 | erofs (system, vendor, product, system_ext) |

Kept from the stock layout: header v2 boot image with offsets as stock, the stock partition sizes and super
group size, A/B with QTI's boot control HAL (ABL reads the GPT slot attributes).

## Getting the source

1. `repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs`
2. Copy `go7ml.xml` (this repo) to `.repo/local_manifests/go7ml.xml` (not together with the Go7 one: both
   list `hardware/onyx`). It adds:
   - `device/onyx/Go7ml` (this tree), `vendor/onyx/Go7ml` (firmware, see below)
   - `vendor/onyx/mesa`: `go7-lineage/android_vendor_onyx_mesa` (GPU drivers)
   - `kernel/onyx/sm7225-6.18`: `go7-lineage/android_kernel_onyx_sm7225`, branch `lineage-24.0` (ACK
     `android17-6.18` at `cfe0897fec35` + the Go 7 commits, fragments in `arch/arm64/configs/vendor/onyx/`)
   - `hardware/onyx/eink` (`EinkShimTile`), `hardware/onyx/frontlight` (`frontlightd`)
   - `device/linaro/dragonboard` at `android-17.0.0_r1` (Lineage's manifest doesn't have it): graphics
     makefiles/sepolicy, rmtfs, tqftpserv
3. `repo sync -c -j8 --force-sync --no-clone-bundle --no-tags`
4. `device/onyx/Go7ml/patches/apply.sh` (frameworks/base: QS warmth slider, no overscroll glow/ripple,
   animation scale; system/sepolicy: platform_app may set the frontlight and e-ink mode properties).
5. `source build/envsetup.sh && breakfast Go7ml eng && m bacon`

## Firmware

```
LINUX_FIRMWARE=$(nix build --no-link --print-out-paths nixpkgs#linux-firmware)/lib/firmware \
PACK=<work>/kernel/mainline/firmware/pack.py \
device/onyx/Go7ml/setup-firmware.sh . <stock>/vendor_a/firmware <stock>/modem_image <stock>/bt_image \
    <stock>/system_a/waveform/eink_waveform.wbf
```
writes `vendor/onyx/Go7ml/` (GPU, ADSP/CDSP/modem `.mbn`, Wi-Fi board data + `firmware-5.bin`, BT, the
waveform) and its `Go7ml-vendor.mk`.

## Flashing

Onyx's fastboot has no `flash`; everything goes through EDL, as for Go7: `boot_a`, `dtbo_a`
(`prebuilts/dtbo-zero.img`), `vbmeta_a`, `vbmeta_system_a`, `super`. Slot `_a` only: `super.img` holds just
the `_a` logical partitions, and `super` and `userdata` are shared between the slots, so this replaces a
Go7 install. Wipe `userdata` and `metadata` when coming from Go7 (different vendor, different encryption
setup).

## First-boot aids (remove once it boots reliably)

- `androidboot.selinux=permissive` in `BOARD_KERNEL_CMDLINE`
- `init.go7ml.logdump.sh`: dmesg (init logs there too) to the `logdump` partition every 10 s for 10 min.
  If adb never shows up: EDL, `edl r logdump logdump.bin`, `strings logdump.bin | sed -n '/^=== go7ml/,/^=== END/p'`.

## Open items (need the device or the first build)

1. First build: fix whatever the draft gets wrong (module names, sepolicy neverallows, VINTF).
2. `fstab`: no inline-crypto for the eMMC on 6.18 is assumed (software FBE); check `/sys/block/mmcblk0/queue/crypto`.
3. frontlightd uses `/dev/i2c-3` (stock bus numbering) while the mainline DTS binds `lm3630a_bl` to the same
   chip: either give `i2c10` the alias `i2c3` and disable the lm3630a node for Android, or teach frontlightd
   the backlight sysfs.
4. Charger/fuel gauge: label their `power_supply` sysfs paths `sysfs_batteryinfo` (`genfs_contexts`).
5. Wi-Fi: check the overlay's softAP features (ACS, SAE) against ath10k; tqftpserv must find
   `wlanmdsp.mbn` (it is under `/vendor/firmware/qcom/sm7225/onyx-go7/`).
6. Wi-Fi/modem: the DT has no `qcom,rmtfs-mem` region yet (stock allocates it dynamically, 0x280000 bytes;
   the FP4 hardcodes the address its modem expects). Read the address on stock (kernel.md T-RM1) and add
   the node to the kernel DTS; until then rmtfs fails and the modem DSP (Wi-Fi) likely doesn't come up.
7. Power HAL, thermal, lights (button LED): not chosen yet.
8. Composer device: `init.go7ml.drm.sh` (exec_start at early-boot) sets `vendor.hwc.drm.device` to the onyx-epd
   card; check `getprop vendor.hwc.drm.device` and that `/sys/class/drm/<that card>/device/driver` is onyx-epd.
   Its `r_dir_file(…, sysfs)` may trip a neverallow at the first build; then label the DRM sysfs nodes instead.
