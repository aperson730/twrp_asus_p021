# Firmware layout and the 900 MHz CPU limit (P021)

Findings from 2026-11-13. Read-only analysis of the stock update file; nothing was flashed.
No ASUS/Intel binaries are included here, only offsets and values.

## fwu_image.bin layout

`fwu_image.bin` (from `UL-P021-WW-4.6.5.0-user.zip`, 32,129,536 bytes) starts with a 512-byte
table of little-endian `uint32` quadruples: `(id, 8, start_sector, length_bytes)`, with
`offset = start_sector * 512`. The first row is a header. The IDs are the same numbers as the
`ImcPartIDxxx` partition names. Same format as
[fwu-shredder](https://github.com/InvisiBot/fwu-shredder).

| id | name | offset | length |
| --- | --- | --- | --- |
| 123 | vrl | 2048 | 131072 |
| 0 | psi_flash | 133120 | 114688 |
| 16 | slb | 247808 | 532216 |
| 113 | ucode_patch | 780288 | 7168 |
| 13 | splash_img | 787456 | 12310016 |
| 115 | mvconfig_smp | 13097472 | 42654 |
| 1 | mobilevisor (hypervisor) | 13140480 | 672160 |
| 118 | secvm | 13812736 | 1224008 |
| 71 | boot | 15036928 | 8286208 |
| 121 | recovery | 23323136 | 8806400 |
| 114, 68, 69, 70 | radio, system, data, cache | - | 0 (not in this file) |

The boot entry matches the earlier `dd` split (ANDROID! header at 15036928) and the boot-backup
check (`cmp -n 8286208`), which confirms the format.

Public reflash instructions for SoFIA devices flash `vrl` first, then the other parts with
`fastboot flash`, so `vrl` is probably the verification record the others are checked against.
Not tested here. **Never flash any of these parts**: they run before fastboot, so a bad one can
leave no way to recover except Intel's low-level USB download mode.

## Where the 416/728/900 MHz steps come from

- Kernel: `drivers/cpufreq/xgold-cpufreq.c`. The device tree `cpufreq` node has
  `intel,table-from-vmm`, so the driver asks the hypervisor for the steps
  (`sofia_get_cpu_nb_freq`, `sofia_get_cpu_freq_table`, i.e. `mv_svc_pm_control`
  `PM_CPU_GET_NUM_FREQ_STEPS` / `PM_CPU_GET_FREQ_STEPS`). The hypervisor answers 416000,
  728000, 900000 kHz. Frequency changes are also requests to the hypervisor
  (`PM_REQ_FREQ_CHNG`); it sets clocks and voltages.
- Device tree fallback: `intel,cpufreq-table = <416000 728000 900000>`,
  `intel,start-freq-limits = <416000 900000>`.
- So the kernel does not cap the CPU. Editing the kernel or device tree cannot add a step.

## The hypervisor knows clocks up to 1.2 GHz

`mobilevisor.bin` offset `0xd840` holds a table of 16-byte entries
`(u32 a, u32 freq_hz, u32 b, u32 c)`:

| offset | a | freq | b | c |
| --- | --- | --- | --- | --- |
| 0xd840 | 0 | 26 MHz | 2 | 2 |
| 0xd850 | 0 | 208 MHz | 32 | 3 |
| 0xd860 | 1 | 312 MHz | 64 | 12 |
| 0xd870 | 1 | 416 MHz | 128 | 3 |
| 0xd880-0xd8a0 | 1 | 728 MHz (3 entries) | 16 | 4 |
| 0xd8b0 | 1 | 900 MHz | 16 | 4 |
| 0xd8c0 | 4 | 1000 MHz | 16 | 4 |
| 0xd8d0 | 5 | 1040 MHz | 16 | 4 |
| 0xd8e0 | 6 | 1050 MHz | 16 | 4 |
| 0xd8f0 | 7 | 1160 MHz | 16 | 4 |
| 0xd900 | 9 | 1200 MHz | 16 | 4 |

A second table follows at `0xd910` (26, 104, 156, 400, 416 MHz): probably another clock domain
(GPU or bus). Column `a` changes exactly above 900 MHz; it may be a voltage or PLL index
(unconfirmed).

`mvconfig_smp.bin` is the VM configuration: boot modes (`normal`, `recovery`, `fastboot`,
`chargeonly`, `kdump`, ...), virtual interrupts (`CPU_CLK_NOTIFY`, `MODEM_DVFS`,
`SPCU_THERM0..5_LOW/HIGH`, `VM_VERIFY`, ...), virtual devices (`mvpipe`, `veth0/1`, `vsec_tee`,
`secmd`, `vpu_*`) and guest command lines (`vvfs=(179,3) vsecmd=... vgps=... vbt=...`). It holds
no list of CPU frequency steps.

## Conclusion

The hypervisor code itself picks 416/728/900 MHz out of a clock table that reaches 1200 MHz.
A likely reason is the chip's fused speed grade (common on Intel parts sold as several SKUs),
but that is not verified; finding out needs disassembly of the code that reads the table.
Using a higher step would mean modifying and flashing the hypervisor: probably blocked by the
`vrl` signature check, with a brick risk, and possibly unstable if the chip is fused for 900 MHz.

Separately: stock *recovery* caps the CPU at 728 MHz (`thermal_scaling_max_freq 728000` in
`init.recovery.sofia3g.rc`, also in this TWRP tree). Stock Android does not; it runs up to
900 MHz with the `interactive` governor.
