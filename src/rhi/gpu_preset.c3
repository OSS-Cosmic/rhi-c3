// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Known desktop GPUs and the preset level each one should default to,
// keyed by PCI vendor and device ID.
module rhi;

enum PresetLevel : char
{
	NONE,
	OFFICE, // this means unsupported
	VERY_LOW, // mostly for mobile gpu
	LOW,
	MEDIUM,
	HIGH,
	ULTRA,
}

struct GpuPreset
{
	uint vendor_id;
	uint model_id;
	PresetLevel preset_level;
}

const GpuPreset[*] DESKTOP_PRESETS = {
	//#intel
	{ 0x8086, 0x0042, VERY_LOW }, //Intel; Intel(R) HD Graphics - Core i3/i5 + Pentium G9650 Processors
	{ 0x8086, 0x0046, VERY_LOW }, //Intel; Intel(R) HD Graphics - Core i3/i5/i7 Mobile Processors
	{ 0x8086, 0x0102, VERY_LOW }, //Intel; Intel(R) HD Graphics 2000
	{ 0x8086, 0x0106, VERY_LOW }, //Intel; Intel(R) HD Graphics 2000
	{ 0x8086, 0x010A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0112, VERY_LOW }, //Intel; Intel(R) HD Graphics 3000
	{ 0x8086, 0x0116, VERY_LOW }, //Intel; Intel(R) HD Graphics 3000
	{ 0x8086, 0x0122, VERY_LOW }, //Intel; Intel(R) HD Graphics 3000
	{ 0x8086, 0x0126, VERY_LOW }, //Intel; Intel(R) HD Graphics 3000
	{ 0x8086, 0x0152, VERY_LOW }, //Intel; Intel(R) HD Graphics 2500
	{ 0x8086, 0x0156, VERY_LOW }, //Intel; Intel(R) HD Graphics 2500
	{ 0x8086, 0x015A, VERY_LOW }, //Intel; Intel(R) HD Graphics 2500
	{ 0x8086, 0x0162, VERY_LOW }, //Intel; Intel(R) HD Graphics 4000
	{ 0x8086, 0x0166, VERY_LOW }, //Intel; Intel(R) HD Graphics 4000
	{ 0x8086, 0x016A, VERY_LOW }, //Intel; Intel(R) HD Graphics 4000
	{ 0x8086, 0x0402, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0406, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x040A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x040B, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x040E, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0412, VERY_LOW }, //Intel; Intel(R) HD Graphics 4600
	{ 0x8086, 0x0416, VERY_LOW }, //Intel; Intel(R) HD Graphics 4600
	{ 0x8086, 0x041A, VERY_LOW }, //Intel; Intel(R) HD Graphics P4600/P4700
	{ 0x8086, 0x041B, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x041E, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0422, VERY_LOW }, //Intel; Intel(R) HD Graphics 5000
	{ 0x8086, 0x0426, VERY_LOW }, //Intel; Intel(R) HD Graphics 5000
	{ 0x8086, 0x042A, VERY_LOW }, //Intel; Intel(R) HD Graphics 5000
	{ 0x8086, 0x042B, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x042E, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0900, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0901, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0902, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0903, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0904, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0A02, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0BD0, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0BD1, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0BD2, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0BD3, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0BD4, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C02, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C06, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C0A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C12, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C16, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C1A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C22, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C26, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0C2A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x0F30, VERY_LOW }, //Intel; Intel(R) Vallyview Graphics
	{ 0x8086, 0x0F31, VERY_LOW }, //Intel; Intel(R) Vallyview Graphics
	{ 0x8086, 0x1602, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1606, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x160A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x160B, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x160D, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x160E, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1612, VERY_LOW }, //Intel; Intel(R) HD Graphics 5600
	{ 0x8086, 0x1616, VERY_LOW }, //Intel; Intel(R) HD Graphics 5500
	{ 0x8086, 0x161A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x161B, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x161D, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x161E, VERY_LOW }, //Intel; Intel(R) HD Graphics 5300
	{ 0x8086, 0x1622, VERY_LOW }, //Intel; Intel(R) Iris(TM) Pro Graphics 6200
	{ 0x8086, 0x1626, VERY_LOW }, //Intel; Intel(R) HD Graphics 6000
	{ 0x8086, 0x162A, VERY_LOW }, //Intel; Intel(R) Iris(TM) Pro Graphics P6300
	{ 0x8086, 0x162B, VERY_LOW }, //Intel; Intel(R) Iris(TM) Graphics 6100
	{ 0x8086, 0x162D, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x162E, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1632, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1636, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x163A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x163B, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x163D, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x163E, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1902, LOW }, //Intel; Intel(R) HD Graphics 510
	{ 0x8086, 0x1906, LOW }, //Intel; Intel(R) HD Graphics 510
	{ 0x8086, 0x190A, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x190B, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x190E, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1912, LOW }, //Intel; Intel(R) HD Graphics 530
	{ 0x8086, 0x1913, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1916, LOW }, //Intel; Intel(R) HD Graphics 520
	{ 0x8086, 0x191A, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x191B, LOW }, //Intel; Intel(R) HD Graphics 530
	{ 0x8086, 0x191D, LOW }, //Intel; Intel(R) HD Graphics P530
	{ 0x8086, 0x191E, LOW }, //Intel; Intel(R) HD Graphics 515
	{ 0x8086, 0x1921, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1923, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x1926, LOW }, //Intel; Intel(R) Iris Graphics 540
	{ 0x8086, 0x1927, LOW }, //Intel; Intel(R) Iris Graphics 540
	{ 0x8086, 0x192A, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x192B, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x192D, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x193A, LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x193B, MEDIUM }, //Intel; Intel(R) Iris Pro Graphics 580
	{ 0x8086, 0x193D, MEDIUM }, //Intel; Intel(R) Iris Pro Graphics P580
	{ 0x8086, 0x22B0, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x22B1, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x22B2, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x22B3, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x2982, VERY_LOW }, //Intel; Intel(R) G35 Express Chipset Family
	{ 0x8086, 0x2983, VERY_LOW }, //Intel; Intel(R) G35 Express Chipset Family
	{ 0x8086, 0x2A02, VERY_LOW }, //Intel; Mobile Intel(R) 965 Express Chipset Family
	{ 0x8086, 0x2A03, VERY_LOW }, //Intel; Mobile Intel(R) 965 Express Chipset Family
	{ 0x8086, 0x2A12, VERY_LOW }, //Intel; Mobile Intel(R) 965 Express Chipset Family
	{ 0x8086, 0x2A13, VERY_LOW }, //Intel; Mobile Intel(R) 965 Express Chipset Family
	{ 0x8086, 0x2A42, VERY_LOW }, //Intel; Mobile Intel(R) 4 Series Express Chipset Family
	{ 0x8086, 0x2A43, VERY_LOW }, //Intel; Mobile Intel(R) 4 Series Express Chipset Family
	{ 0x8086, 0x2E02, VERY_LOW }, //Intel; Intel(R) 4 Series Express Chipset
	{ 0x8086, 0x2E03, VERY_LOW }, //Intel; Intel(R) 4 Series Express Chipset
	{ 0x8086, 0x2E12, VERY_LOW }, //Intel; Intel(R) Q45/Q43 Express Chipset
	{ 0x8086, 0x2E13, VERY_LOW }, //Intel; Intel(R) Q45/Q43 Express Chipset
	{ 0x8086, 0x2E22, VERY_LOW }, //Intel; Intel(R) G45/G43 Express Chipset
	{ 0x8086, 0x2E23, VERY_LOW }, //Intel; Intel(R) G45/G43 Express Chipset
	{ 0x8086, 0x2E32, VERY_LOW }, //Intel; Intel(R) G41 Express Chipset
	{ 0x8086, 0x2E33, VERY_LOW }, //Intel; Intel(R) G41 Express Chipset
	{ 0x8086, 0x2E42, VERY_LOW }, //Intel; Intel(R) B43 Express Chipset
	{ 0x8086, 0x2E43, VERY_LOW }, //Intel; Intel(R) B43 Express Chipset
	{ 0x8086, 0x2E92, VERY_LOW }, //Intel; Intel(R) B43 Express Chipset
	{ 0x8086, 0x2E93, VERY_LOW }, //Intel; Intel(R) B43 Express Chipset
	{ 0x8086, 0x3184, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3185, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E90, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E91, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E92, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E93, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E94, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E96, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E98, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E99, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E9A, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E9B, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3E9C, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3EA0, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3EA1, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3EA2, MEDIUM }, //Intel; Intel(R) Iris Plus Graphics
	{ 0x8086, 0x3EA3, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3EA4, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x3EA5, MEDIUM }, //Intel; Intel(R) Iris Plus Graphics
	{ 0x8086, 0x3EA6, MEDIUM }, //Intel; Intel(R) Iris Plus Graphics
	{ 0x8086, 0x3EA7, MEDIUM }, //Intel; Intel(R) Iris Plus Graphics
	{ 0x8086, 0x3EA8, MEDIUM }, //Intel; Intel(R) Iris Plus Graphics
	{ 0x8086, 0x3EA9, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x4626, LOW }, //Intel; , Intel(R) Xe Graphics
	{ 0x8086, 0x4680, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x4682, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x4688, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x468A, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x468B, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x4690, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x4692, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x4693, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x46A3, LOW }, //Intel; , Intel(R) Xe Graphics
	{ 0x8086, 0x46A6, LOW }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0x4905, LOW }, //Intel; Intel(R) Iris(R) Xe MAX Graphics
	{ 0x8086, 0x4906, LOW }, //Intel; Intel(R) Iris(R) Xe MAX Graphics
	{ 0x8086, 0x4907, LOW }, //Intel; Intel(R) Iris(R) Xe MAX Graphics
	{ 0x8086, 0x4C8A, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x4C8B, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x4C90, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x5690, MEDIUM }, //Intel; Intel(R) Arc(TM) A770M Graphics
	{ 0x8086, 0x5693, MEDIUM }, //Intel; Intel(R) Arc(TM) A370M Graphics
	{ 0x8086, 0x56A0, MEDIUM }, //Intel; Intel(R) Arc(TM) A770 Graphics
	{ 0x8086, 0x56A1, MEDIUM }, //Intel; Intel(R) Arc(TM) A750 Graphics
	{ 0x8086, 0x56A5, MEDIUM }, //Intel; Intel(R) Arc(TM) A380 Graphics
	{ 0x8086, 0x5902, VERY_LOW }, //Intel; Intel(R) HD Graphics 610
	{ 0x8086, 0x5906, VERY_LOW }, //Intel; Intel(R) HD Graphics 610
	{ 0x8086, 0x5908, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x590A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x590B, VERY_LOW }, //Intel; Intel(R) HD Graphics P610
	{ 0x8086, 0x590E, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5912, LOW }, //Intel; Intel(R) HD Graphics 630
	{ 0x8086, 0x5913, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5915, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5916, LOW }, //Intel; Intel(R) HD Graphics 620
	{ 0x8086, 0x5917, LOW }, //Intel; Intel(R) UHD Graphics 620
	{ 0x8086, 0x591A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x591B, LOW }, //Intel; Intel(R) HD Graphics 630
	{ 0x8086, 0x591C, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x591D, LOW }, //Intel; Intel(R) HD Graphics P630
	{ 0x8086, 0x591E, VERY_LOW }, //Intel; Intel(R) HD Graphics 615
	{ 0x8086, 0x5921, LOW }, //Intel; Intel(R) HD Graphics 620
	{ 0x8086, 0x5923, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5926, MEDIUM }, //Intel; Intel(R) Iris Plus Graphics 640
	{ 0x8086, 0x5927, MEDIUM }, //Intel; Intel(R) Iris Plus Graphics 650
	{ 0x8086, 0x592A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x592B, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5932, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x593A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x593B, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x593D, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A40, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A41, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A42, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A44, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A49, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A4A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A4C, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A50, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A51, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A52, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A54, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A59, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A5A, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x5A5C, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x87C0, VERY_LOW }, //Intel; Intel(R) HD Graphics
	{ 0x8086, 0x87CA, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x8A50, LOW }, //Intel; Intel(R) Iris Plus Graphics (64 EUs)
	{ 0x8086, 0x8A51, LOW }, //Intel; Intel(R) Iris Plus Graphics (64 EUs)
	{ 0x8086, 0x8A52, LOW }, //Intel; Intel(R) Iris Plus Graphics (64 EUs)
	{ 0x8086, 0x8A53, LOW }, //Intel; Intel(R) Iris Plus Graphics (64 EUs)
	{ 0x8086, 0x8A54, LOW }, //Intel; Intel(R) Iris Plus Graphics (48 EUs)
	{ 0x8086, 0x8A56, LOW }, //Intel; Intel(R) Iris Plus Graphics (48 EUs)
	{ 0x8086, 0x8A57, LOW }, //Intel; Intel(R) Iris Plus Graphics (48 EUs)
	{ 0x8086, 0x8A58, LOW }, //Intel; Intel(R) Iris Plus Graphics (32 EUs)
	{ 0x8086, 0x8A59, LOW }, //Intel; Intel(R) Iris Plus Graphics (48 EUs)
	{ 0x8086, 0x8A5A, LOW }, //Intel; Intel(R) Iris Plus Graphics (48 EUs)
	{ 0x8086, 0x8A5B, LOW }, //Intel; Intel(R) Iris Plus Graphics (32 EUs)
	{ 0x8086, 0x8A5C, LOW }, //Intel; Intel(R) Iris Plus Graphics (48 EUs)
	{ 0x8086, 0x8A5D, LOW }, //Intel; Intel(R) Iris Plus Graphics (32 EUs)
	{ 0x8086, 0x8A71, LOW }, //Intel; Intel(R) Iris Plus Graphics (8 EUs)
	{ 0x8086, 0x9A40, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9A49, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9A59, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9A60, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9A68, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9A70, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9A78, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9A7F, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9AC0, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9AC9, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9AD9, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9AF8, LOW }, //Intel; Intel(R) Iris(R) Xe Graphics
	{ 0x8086, 0x9B21, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9B41, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BA0, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BA2, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BA4, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BA5, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BA8, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BAA, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BAB, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BAC, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BC0, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BC2, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BC4, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BC5, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BC6, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BC8, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BCA, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BCB, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BCC, LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BE6, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0x9BF6, VERY_LOW }, //Intel; Intel(R) UHD Graphics
	{ 0x8086, 0xA780, MEDIUM }, //Intel; Intel(R) Xe Graphics
	{ 0x8086, 0xA788, MEDIUM }, //Intel; Intel(R) Xe Graphics

	// amd
	{ 0x1002, 0x1309, VERY_LOW }, //AMD; AMD Radeon(TM) R7 Graphics
	{ 0x1002, 0x130A, VERY_LOW }, //AMD; AMD Radeon(TM) R6 Graphics
	{ 0x1002, 0x130D, VERY_LOW }, //AMD; AMD Radeon(TM) R6 Graphics
	{ 0x1002, 0x130F, VERY_LOW }, //AMD; AMD Radeon(TM) R7 Graphics
	{ 0x1002, 0x1313, VERY_LOW }, //AMD; AMD Radeon(TM) R7 Graphics
	{ 0x1002, 0x15BF, VERY_LOW }, //AMD; AMD Radeon (TM) 740M Graphics
	{ 0x1002, 0x15D8, VERY_LOW }, //AMD; AMD 15D8:C8
	{ 0x1002, 0x15DD, VERY_LOW }, //AMD; AMD Radeon(TM) RX Vega 10 Graphics
	{ 0x1002, 0x15E7, VERY_LOW }, //AMD; AMD Radeon (TM) Graphics
	{ 0x1002, 0x163F, VERY_LOW }, //AMD; AMD Custom GPU 0405
	{ 0x1002, 0x164E, VERY_LOW }, //AMD; AMD Radeon(TM) 610M
	{ 0x1002, 0x1681, VERY_LOW }, //AMD; AMD Radeon (TM) Graphics
	{ 0x1002, 0x6600, VERY_LOW }, //AMD; AMD Radeon (TM) R7 M370
	{ 0x1002, 0x6601, VERY_LOW }, //AMD; AMD Radeon (TM) HD 8500M/8700M
	{ 0x1002, 0x6604, VERY_LOW }, //AMD; AMD Radeon (TM) R7 M350
	{ 0x1002, 0x6605, VERY_LOW }, //AMD; AMD FirePro M4150
	{ 0x1002, 0x6606, VERY_LOW }, //AMD; AMD Radeon HD 8790M
	{ 0x1002, 0x6608, VERY_LOW }, //AMD; AMD FirePro W2100
	{ 0x1002, 0x6610, VERY_LOW }, //AMD; AMD Radeon (TM) R5 340
	{ 0x1002, 0x6611, VERY_LOW }, //AMD; AMD Radeon HD 8570
	{ 0x1002, 0x6613, VERY_LOW }, //AMD; AMD Radeon R7 240
	{ 0x1002, 0x6640, VERY_LOW }, //AMD; AMD FirePro M6100
	{ 0x1002, 0x6646, VERY_LOW }, //AMD; AMD Radeon (TM) R9 M470X
	{ 0x1002, 0x6660, VERY_LOW }, //AMD; AMD Radeon (TM) 520
	{ 0x1002, 0x6665, VERY_LOW }, //AMD; AMD Radeon (TM) R5 M320
	{ 0x1002, 0x666F, VERY_LOW }, //AMD; AMD Radeon HD 8500M
	{ 0x1002, 0x66A1, MEDIUM }, //AMD; AMD Radeon Pro VII
	{ 0x1002, 0x66AF, HIGH }, //AMD; AMD Radeon VII
	{ 0x1002, 0x67A0, VERY_LOW }, //AMD; AMD FirePro S9150
	{ 0x1002, 0x67B0, LOW }, //AMD; AMD Radeon(TM) R9 290X
	{ 0x1002, 0x67C4, MEDIUM }, //AMD; AMD Radeon (TM) Pro WX 7100 Graphics
	{ 0x1002, 0x67C7, LOW }, //AMD; Radeon (TM) Pro WX 5100 Graphics
	{ 0x1002, 0x67DF, MEDIUM }, //AMD; AMD Radeon (TM) RX 480
	{ 0x1002, 0x67E3, VERY_LOW }, //AMD; Radeon (TM) Pro WX 4100
	{ 0x1002, 0x67E8, VERY_LOW }, //AMD; Radeon(TM) Pro WX 4150 Graphics
	{ 0x1002, 0x67EF, VERY_LOW }, //AMD; AMD Radeon Pro 460
	{ 0x1002, 0x6801, VERY_LOW }, //AMD; AMD Radeon(TM) HD8970M
	{ 0x1002, 0x6808, LOW }, //AMD; AMD FirePro W7000
	{ 0x1002, 0x6810, VERY_LOW }, //AMD; AMD FirePro D300
	{ 0x1002, 0x6820, VERY_LOW }, //AMD; AMD FirePro W5170M
	{ 0x1002, 0x6821, VERY_LOW }, //AMD; AMD FirePro M5100
	{ 0x1002, 0x682B, VERY_LOW }, //AMD; AMD Radeon (TM) R9 M360
	{ 0x1002, 0x682C, VERY_LOW }, //AMD; AMD FirePro W4100
	{ 0x1002, 0x683D, VERY_LOW }, //AMD; AMD Radeon HD 7770 GHz Edition
	{ 0x1002, 0x6861, MEDIUM }, //AMD; Radeon (TM) Pro WX 9100
	{ 0x1002, 0x6863, MEDIUM }, //AMD; Radeon Vega Frontier Edition
	{ 0x1002, 0x6869, MEDIUM }, //AMD; Radeon Pro Vega 48
	{ 0x1002, 0x686B, MEDIUM }, //AMD; Radeon Pro Vega 64X
	{ 0x1002, 0x687F, MEDIUM }, //AMD; Radeon RX Vega
	{ 0x1002, 0x6900, VERY_LOW }, //AMD; AMD Radeon (TM) 535DX
	{ 0x1002, 0x6901, VERY_LOW }, //AMD; AMD Radeon R5 M255
	{ 0x1002, 0x6920, LOW }, //AMD; AMD RADEON R9 M395X
	{ 0x1002, 0x6929, VERY_LOW }, //AMD; AMD FirePro S7150
	{ 0x1002, 0x692B, LOW }, //AMD; AMD FirePro W7100
	{ 0x1002, 0x6938, LOW }, //AMD; AMD RADEON R9 M295X
	{ 0x1002, 0x694C, LOW }, //AMD; Radeon RX Vega M GH Graphics
	{ 0x1002, 0x694E, VERY_LOW }, //AMD; Radeon RX Vega M GL Graphics
	{ 0x1002, 0x699F, VERY_LOW }, //AMD; AMD Embedded Radeon E9175
	{ 0x1002, 0x69AF, LOW }, //AMD; Radeon Pro Vega 20
	{ 0x1002, 0x6FDF, LOW }, //AMD; AMD Radeon RX 580 2048SP
	{ 0x1002, 0x7300, MEDIUM }, //AMD; Radeon (TM) Pro Duo
	{ 0x1002, 0x7312, MEDIUM }, //AMD; AMD Radeon Pro W5700
	{ 0x1002, 0x731F, MEDIUM }, //AMD; AMD Radeon RX 5600 XT
	{ 0x1002, 0x7340, LOW }, //AMD; AMD Radeon Pro 5300
	{ 0x1002, 0x7341, MEDIUM }, //AMD; AMD Radeon Pro W5500
	{ 0x1002, 0x7360, MEDIUM }, //AMD; AMD Radeon Pro 5600M
	{ 0x1002, 0x7362, LOW }, //AMD; AMD Radeon Pro V520 MxGPU
	{ 0x1002, 0x73A3, HIGH }, //AMD; AMD Radeon PRO W6800
	{ 0x1002, 0x73A5, HIGH }, //AMD; AMD Radeon RX 6950 XT
	{ 0x1002, 0x73AB, LOW }, //AMD; AMD Radeon Pro W6800X
	{ 0x1002, 0x73AF, HIGH }, //AMD; AMD Radeon RX 6900 XT
	{ 0x1002, 0x73BF, HIGH }, //AMD; AMD Radeon RX 6800
	{ 0x1002, 0x73DF, HIGH }, //AMD; AMD Radeon RX 6700
	{ 0x1002, 0x73E3, HIGH }, //AMD; AMD Radeon PRO W6600
	{ 0x1002, 0x73EF, HIGH }, //AMD; AMD Radeon RX 6650 XT
	{ 0x1002, 0x73FF, MEDIUM }, //AMD; AMD Radeon RX 6600
	{ 0x1002, 0x7422, MEDIUM }, //AMD; AMD Radeon PRO W6400
	{ 0x1002, 0x743F, LOW }, //AMD; AMD Radeon RX 6400
	{ 0x1002, 0x744C, HIGH }, //AMD; AMD Radeon RX 7900 XT
	{ 0x1002, 0x747E, HIGH }, //AMD; AMD Radeon RX 7700 XT
	{ 0x1002, 0x7480, HIGH }, //AMD; AMD Radeon RX 7600
	{ 0x1002, 0x9832, VERY_LOW }, //AMD; AMD Radeon HD 8330
	{ 0x1002, 0x9834, OFFICE }, //AMD; AMD Radeon HD 8210
	{ 0x1002, 0x9850, VERY_LOW }, //AMD; AMD Radeon(TM) R2 Graphics
	{ 0x1002, 0x9851, VERY_LOW }, //AMD; AMD Radeon(TM) R4 Graphics
	{ 0x1002, 0x9853, VERY_LOW }, //AMD; AMD Radeon(TM) R2 Graphics
	{ 0x1002, 0x9874, VERY_LOW }, //AMD; AMD Radeon R5 Graphics
	{ 0x1002, 0x98E4, VERY_LOW }, //AMD; AMD Radeon(TM) R2 Graphics

	// #nvidia
	{ 0x10DE, 0x1001, MEDIUM }, //NVIDIA; GeForce GTX TITAN Z
	{ 0x10DE, 0x1004, MEDIUM }, //NVIDIA; GeForce GTX 780
	{ 0x10DE, 0x1005, MEDIUM }, //NVIDIA; GeForce GTX TITAN
	{ 0x10DE, 0x100A, MEDIUM }, //NVIDIA; GeForce GTX 780 Ti
	{ 0x10DE, 0x100C, MEDIUM }, //NVIDIA; GeForce GTX TITAN Black
	{ 0x10DE, 0x1023, VERY_LOW }, //NVIDIA; Tesla K40m
	{ 0x10DE, 0x103A, MEDIUM }, //NVIDIA; Quadro K6000
	{ 0x10DE, 0x103C, LOW }, //NVIDIA; Quadro K5200
	{ 0x10DE, 0x1180, LOW }, //NVIDIA; GeForce GTX 680
	{ 0x10DE, 0x1183, LOW }, //NVIDIA; GeForce GTX 660 Ti
	{ 0x10DE, 0x1184, LOW }, //NVIDIA; GeForce GTX 770
	{ 0x10DE, 0x1185, LOW }, //NVIDIA; GeForce GTX 660
	{ 0x10DE, 0x1187, LOW }, //NVIDIA; GeForce GTX 760
	{ 0x10DE, 0x1188, LOW }, //NVIDIA; GeForce GTX 690
	{ 0x10DE, 0x1189, LOW }, //NVIDIA; GeForce GTX 670
	{ 0x10DE, 0x118E, LOW }, //NVIDIA; GeForce GTX 760 (192-bit)
	{ 0x10DE, 0x1198, VERY_LOW }, //NVIDIA; GeForce GTX 880M
	{ 0x10DE, 0x1199, VERY_LOW }, //NVIDIA; GeForce GTX 870M
	{ 0x10DE, 0x119A, VERY_LOW }, //NVIDIA; GeForce GTX 860M
	{ 0x10DE, 0x119E, VERY_LOW }, //NVIDIA; GeForce GTX 780M
	{ 0x10DE, 0x119F, VERY_LOW }, //NVIDIA; GeForce GTX 780M
	{ 0x10DE, 0x11A1, VERY_LOW }, //NVIDIA; GeForce GTX 670MX
	{ 0x10DE, 0x11A3, LOW }, //NVIDIA; GeForce GTX 680MX
	{ 0x10DE, 0x11A7, VERY_LOW }, //NVIDIA; GeForce GTX 675MX
	{ 0x10DE, 0x11B4, LOW }, //NVIDIA; Quadro K4200
	{ 0x10DE, 0x11B6, VERY_LOW }, //NVIDIA; Quadro K3100M
	{ 0x10DE, 0x11B7, VERY_LOW }, //NVIDIA; Quadro K4100M
	{ 0x10DE, 0x11B8, VERY_LOW }, //NVIDIA; Quadro K5100M
	{ 0x10DE, 0x11BC, VERY_LOW }, //NVIDIA; Quadro K5000M
	{ 0x10DE, 0x11BE, VERY_LOW }, //NVIDIA; Quadro K3000M
	{ 0x10DE, 0x11C0, LOW }, //NVIDIA; GeForce GTX 660
	{ 0x10DE, 0x11C2, VERY_LOW }, //NVIDIA; GeForce GTX 650 Ti BOOST
	{ 0x10DE, 0x11C4, VERY_LOW }, //NVIDIA; GeForce GTX 645
	{ 0x10DE, 0x11C6, VERY_LOW }, //NVIDIA; GeForce GTX 650 Ti
	{ 0x10DE, 0x11C8, VERY_LOW }, //NVIDIA; GeForce GTX 650
	{ 0x10DE, 0x11E0, VERY_LOW }, //NVIDIA; GeForce GTX 770M
	{ 0x10DE, 0x11E1, VERY_LOW }, //NVIDIA; NVIDIA GeForce GTX 765M
	{ 0x10DE, 0x11E2, VERY_LOW }, //NVIDIA; GeForce GTX 765M
	{ 0x10DE, 0x11E3, VERY_LOW }, //NVIDIA; GeForce GTX 760M
	{ 0x10DE, 0x11FA, VERY_LOW }, //NVIDIA; Quadro K4000
	{ 0x10DE, 0x11FC, VERY_LOW }, //NVIDIA; K2100M
	{ 0x10DE, 0x1280, VERY_LOW }, //NVIDIA; GeForce GT 635
	{ 0x10DE, 0x1281, VERY_LOW }, //NVIDIA; GT 710
	{ 0x10DE, 0x1282, VERY_LOW }, //NVIDIA; NVIDIA GeForce GT 640
	{ 0x10DE, 0x1284, VERY_LOW }, //NVIDIA; GeForce GT 630
	{ 0x10DE, 0x1286, VERY_LOW }, //NVIDIA; GeForce GT 720
	{ 0x10DE, 0x1287, VERY_LOW }, //NVIDIA; GeForce GT 730
	{ 0x10DE, 0x1288, VERY_LOW }, //NVIDIA; GeForce GT 720
	{ 0x10DE, 0x128B, VERY_LOW }, //NVIDIA; GeForce GT 710
	{ 0x10DE, 0x1290, VERY_LOW }, //NVIDIA; GeForce GT 730M
	{ 0x10DE, 0x1292, VERY_LOW }, //NVIDIA; GeForce GT 740M
	{ 0x10DE, 0x1295, VERY_LOW }, //NVIDIA; GeForce 810A
	{ 0x10DE, 0x1299, VERY_LOW }, //NVIDIA; 920M
	{ 0x10DE, 0x129A, VERY_LOW }, //NVIDIA; GeForce 910M
	{ 0x10DE, 0x12B9, VERY_LOW }, //NVIDIA; Quadro K610M
	{ 0x10DE, 0x1340, VERY_LOW }, //NVIDIA; NVIDIA GeForce 830M
	{ 0x10DE, 0x1341, VERY_LOW }, //NVIDIA; 840M
	{ 0x10DE, 0x1344, VERY_LOW }, //NVIDIA; GeForce 845M
	{ 0x10DE, 0x1346, VERY_LOW }, //NVIDIA; GeForce 930M
	{ 0x10DE, 0x1347, VERY_LOW }, //NVIDIA; GeForce 940M
	{ 0x10DE, 0x134B, VERY_LOW }, //NVIDIA; NVIDIA GeForce GPU
	{ 0x10DE, 0x134D, VERY_LOW }, //NVIDIA; GeForce 940MX
	{ 0x10DE, 0x134E, VERY_LOW }, //NVIDIA; 930MX
	{ 0x10DE, 0x134F, VERY_LOW }, //NVIDIA; 920MX
	{ 0x10DE, 0x137B, VERY_LOW }, //NVIDIA; Quadro M520
	{ 0x10DE, 0x1380, LOW }, //NVIDIA; GeForce GTX 750 Ti
	{ 0x10DE, 0x1381, VERY_LOW }, //NVIDIA; GeForce GTX 750
	{ 0x10DE, 0x1382, LOW }, //NVIDIA; GeForce GTX 745
	{ 0x10DE, 0x1391, VERY_LOW }, //NVIDIA; GeForce GTX 850M
	{ 0x10DE, 0x1392, VERY_LOW }, //NVIDIA; GeForce GPU
	{ 0x10DE, 0x139A, VERY_LOW }, //NVIDIA; GeForce GTX 950M
	{ 0x10DE, 0x139B, VERY_LOW }, //NVIDIA; GeForce GTX 960M
	{ 0x10DE, 0x139C, VERY_LOW }, //NVIDIA; NVIDIA GeForce 940M
	{ 0x10DE, 0x13B0, VERY_LOW }, //NVIDIA; Quadro M2000M
	{ 0x10DE, 0x13B1, VERY_LOW }, //NVIDIA; M1000M
	{ 0x10DE, 0x13B4, VERY_LOW }, //NVIDIA; Quadro M620
	{ 0x10DE, 0x13B6, VERY_LOW }, //NVIDIA; Quadro M1200
	{ 0x10DE, 0x13BA, VERY_LOW }, //NVIDIA; K2200
	{ 0x10DE, 0x13BB, VERY_LOW }, //NVIDIA; Quadro K620
	{ 0x10DE, 0x13C0, MEDIUM }, //NVIDIA; GeForce GTX 980
	{ 0x10DE, 0x13C2, MEDIUM }, //NVIDIA; GeForce GTX 970
	{ 0x10DE, 0x13D7, LOW }, //NVIDIA; GeForce GTX 980M
	{ 0x10DE, 0x13D8, LOW }, //NVIDIA; GeForce GTX 970M
	{ 0x10DE, 0x13F1, LOW }, //NVIDIA; Quadro M4000
	{ 0x10DE, 0x13F2, LOW }, //NVIDIA; GRID M60-8Q
	{ 0x10DE, 0x13F8, LOW }, //NVIDIA; Quadro M5000M
	{ 0x10DE, 0x13F9, LOW }, //NVIDIA; Quadro M4000M
	{ 0x10DE, 0x13FA, LOW }, //NVIDIA; Quadro M3000M
	{ 0x10DE, 0x1401, LOW }, //NVIDIA; GeForce GTX 960
	{ 0x10DE, 0x1402, LOW }, //NVIDIA; GeForce GTX 950
	{ 0x10DE, 0x1407, VERY_LOW }, //NVIDIA; GeForce GTX 750
	{ 0x10DE, 0x1427, VERY_LOW }, //NVIDIA; GeForce GTX 965M
	{ 0x10DE, 0x1430, LOW }, //NVIDIA; Quadro M2000
	{ 0x10DE, 0x1436, LOW }, //NVIDIA; Quadro M2200
	{ 0x10DE, 0x15F0, HIGH }, //NVIDIA; Quadro GP100
	{ 0x10DE, 0x1617, LOW }, //NVIDIA; NVIDIA GeForce GTX 980M
	{ 0x10DE, 0x1618, LOW }, //NVIDIA; GeForce GTX 970M
	{ 0x10DE, 0x174D, VERY_LOW }, //NVIDIA; GeForce MX130
	{ 0x10DE, 0x174E, VERY_LOW }, //NVIDIA; GeForce MX110
	{ 0x10DE, 0x179C, VERY_LOW }, //NVIDIA; 940MX
	{ 0x10DE, 0x17C2, MEDIUM }, //NVIDIA; GeForce GTX TITAN X
	{ 0x10DE, 0x17C8, MEDIUM }, //NVIDIA; GeForce GTX 980 Ti
	{ 0x10DE, 0x17F0, MEDIUM }, //NVIDIA; Quadro M6000
	{ 0x10DE, 0x17F1, MEDIUM }, //NVIDIA; Quadro M6000 24GB
	{ 0x10DE, 0x1B00, MEDIUM }, //NVIDIA; NVIDIA TITAN X (Pascal)
	{ 0x10DE, 0x1B02, HIGH }, //NVIDIA; NVIDIA TITAN Xp
	{ 0x10DE, 0x1B06, HIGH }, //NVIDIA; GeForce GTX 1080 Ti
	{ 0x10DE, 0x1B30, MEDIUM }, //NVIDIA; Quadro P6000
	{ 0x10DE, 0x1B38, VERY_LOW }, //NVIDIA; GRID P40-4Q
	{ 0x10DE, 0x1B80, HIGH }, //NVIDIA; GeForce GTX 1080
	{ 0x10DE, 0x1B81, MEDIUM }, //NVIDIA; GeForce GTX 1070
	{ 0x10DE, 0x1B82, MEDIUM }, //NVIDIA; GeForce GTX 1070 Ti
	{ 0x10DE, 0x1B83, MEDIUM }, //NVIDIA; GeForce GTX 1060 6GB
	{ 0x10DE, 0x1B84, MEDIUM }, //NVIDIA; NVIDIA GeForce GTX 1060 3GB
	{ 0x10DE, 0x1BA1, LOW }, //NVIDIA; GeForce GTX 1070 with Max-Q Design
	{ 0x10DE, 0x1BB0, MEDIUM }, //NVIDIA; Quadro P5000
	{ 0x10DE, 0x1BB1, MEDIUM }, //NVIDIA; NVIDIA Quadro P4000
	{ 0x10DE, 0x1BB3, MEDIUM }, //NVIDIA; Tesla P4
	{ 0x10DE, 0x1BB5, MEDIUM }, //NVIDIA; Quadro P5200
	{ 0x10DE, 0x1BB6, MEDIUM }, //NVIDIA; Quadro P5000
	{ 0x10DE, 0x1BB7, MEDIUM }, //NVIDIA; NVIDIA Quadro P4000
	{ 0x10DE, 0x1BB8, MEDIUM }, //NVIDIA; Quadro P3000
	{ 0x10DE, 0x1BB9, MEDIUM }, //NVIDIA; Quadro P4200
	{ 0x10DE, 0x1BBB, MEDIUM }, //NVIDIA; Quadro P3200
	{ 0x10DE, 0x1BE0, HIGH }, //NVIDIA; GeForce GTX 1080
	{ 0x10DE, 0x1BE1, MEDIUM }, //NVIDIA; GeForce GTX 1070
	{ 0x10DE, 0x1C02, MEDIUM }, //NVIDIA; GeForce GTX 1060 3GB
	{ 0x10DE, 0x1C03, MEDIUM }, //NVIDIA; GeForce GTX 1060 6GB
	{ 0x10DE, 0x1C04, MEDIUM }, //NVIDIA; GeForce GTX 1060 5GB
	{ 0x10DE, 0x1C06, MEDIUM }, //NVIDIA; GeForce GTX 1060 6GB
	{ 0x10DE, 0x1C07, LOW }, //NVIDIA; P106-100
	{ 0x10DE, 0x1C09, VERY_LOW }, //NVIDIA; P106-090
	{ 0x10DE, 0x1C20, MEDIUM }, //NVIDIA; GeForce GTX 1060
	{ 0x10DE, 0x1C21, LOW }, //NVIDIA; GeForce GTX 1050 Ti
	{ 0x10DE, 0x1C30, LOW }, //NVIDIA; Quadro P2000
	{ 0x10DE, 0x1C31, MEDIUM }, //NVIDIA; Quadro P2200
	{ 0x10DE, 0x1C60, MEDIUM }, //NVIDIA; GeForce GTX 1060
	{ 0x10DE, 0x1C81, LOW }, //NVIDIA; GeForce GTX 1050
	{ 0x10DE, 0x1C82, LOW }, //NVIDIA; GeForce GTX 1050 Ti
	{ 0x10DE, 0x1C8C, LOW }, //NVIDIA; GeForce GTX 1050 Ti
	{ 0x10DE, 0x1C8D, LOW }, //NVIDIA; GeForce GTX 1050
	{ 0x10DE, 0x1C8F, LOW }, //NVIDIA; GeForce GTX 1050 Ti with Max-Q Design
	{ 0x10DE, 0x1C90, VERY_LOW }, //NVIDIA; NVIDIA GeForce MX150
	{ 0x10DE, 0x1C91, LOW }, //NVIDIA; GeForce GTX 1050
	{ 0x10DE, 0x1C92, LOW }, //NVIDIA; GeForce GTX 1050
	{ 0x10DE, 0x1C94, VERY_LOW }, //NVIDIA; NVIDIA GeForce MX350
	{ 0x10DE, 0x1C96, VERY_LOW }, //NVIDIA; GeForce MX350
	{ 0x10DE, 0x1CB2, VERY_LOW }, //NVIDIA; Quadro P600
	{ 0x10DE, 0x1CB3, VERY_LOW }, //NVIDIA; Quadro P400
	{ 0x10DE, 0x1CB6, VERY_LOW }, //NVIDIA; Quadro P620
	{ 0x10DE, 0x1CBA, LOW }, //NVIDIA; Quadro P2000
	{ 0x10DE, 0x1CBB, LOW }, //NVIDIA; Quadro P1000
	{ 0x10DE, 0x1CBC, VERY_LOW }, //NVIDIA; Quadro P600
	{ 0x10DE, 0x1CBD, VERY_LOW }, //NVIDIA; NVIDIA Quadro P620
	{ 0x10DE, 0x1D01, VERY_LOW }, //NVIDIA; GeForce GT 1030
	{ 0x10DE, 0x1D10, VERY_LOW }, //NVIDIA; GeForce MX150
	{ 0x10DE, 0x1D11, VERY_LOW }, //NVIDIA; GeForce MX230
	{ 0x10DE, 0x1D12, VERY_LOW }, //NVIDIA; GeForce MX150
	{ 0x10DE, 0x1D13, VERY_LOW }, //NVIDIA; GeForce MX250
	{ 0x10DE, 0x1D16, VERY_LOW }, //NVIDIA; GeForce MX330
	{ 0x10DE, 0x1D52, VERY_LOW }, //NVIDIA; GeForce MX250
	{ 0x10DE, 0x1D81, HIGH }, //NVIDIA; NVIDIA TITAN V
	{ 0x10DE, 0x1DBA, HIGH }, //NVIDIA; Quadro GV100
	{ 0x10DE, 0x1E02, HIGH }, //NVIDIA; NVIDIA TITAN RTX
	{ 0x10DE, 0x1E04, HIGH }, //NVIDIA; GeForce RTX 2080 Ti
	{ 0x10DE, 0x1E07, HIGH }, //NVIDIA; GeForce RTX 2080 Ti
	{ 0x10DE, 0x1E30, HIGH }, //NVIDIA; Quadro RTX 6000
	{ 0x10DE, 0x1E81, HIGH }, //NVIDIA; GeForce RTX 2080 SUPER
	{ 0x10DE, 0x1E82, HIGH }, //NVIDIA; GeForce RTX 2080
	{ 0x10DE, 0x1E84, HIGH }, //NVIDIA; GeForce RTX 2070 SUPER
	{ 0x10DE, 0x1E87, HIGH }, //NVIDIA; GeForce RTX 2080
	{ 0x10DE, 0x1E89, MEDIUM }, //NVIDIA; GeForce RTX 2060
	{ 0x10DE, 0x1E90, MEDIUM }, //NVIDIA; GeForce RTX 2080 with Max-Q Design
	{ 0x10DE, 0x1E91, HIGH }, //NVIDIA; NVIDIA GeForce RTX 2070 Super
	{ 0x10DE, 0x1E93, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 2080 Super with Max-Q Design
	{ 0x10DE, 0x1EB0, HIGH }, //NVIDIA; Quadro RTX 5000
	{ 0x10DE, 0x1EB1, MEDIUM }, //NVIDIA; Quadro RTX 4000
	{ 0x10DE, 0x1EB5, MEDIUM }, //NVIDIA; NVIDIA Quadro RTX 5000 with Max-Q Design
	{ 0x10DE, 0x1EB6, MEDIUM }, //NVIDIA; Quadro RTX 4000
	{ 0x10DE, 0x1EB8, LOW }, //NVIDIA; GRID T4-2B
	{ 0x10DE, 0x1EC7, HIGH }, //NVIDIA; NVIDIA GeForce RTX 2070 SUPER
	{ 0x10DE, 0x1ED0, HIGH }, //NVIDIA; NVIDIA GeForce RTX 2080
	{ 0x10DE, 0x1ED1, HIGH }, //NVIDIA; NVIDIA GeForce RTX 2070 Super
	{ 0x10DE, 0x1ED3, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 2080 Super with Max-Q Design
	{ 0x10DE, 0x1F02, HIGH }, //NVIDIA; GeForce RTX 2070
	{ 0x10DE, 0x1F03, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 2060
	{ 0x10DE, 0x1F06, HIGH }, //NVIDIA; GeForce RTX 2060 SUPER
	{ 0x10DE, 0x1F07, HIGH }, //NVIDIA; GeForce RTX 2070
	{ 0x10DE, 0x1F08, MEDIUM }, //NVIDIA; GeForce RTX 2060
	{ 0x10DE, 0x1F0A, MEDIUM }, //NVIDIA; NVIDIA GeForce GTX 1650
	{ 0x10DE, 0x1F10, HIGH }, //NVIDIA; GeForce RTX 2070
	{ 0x10DE, 0x1F11, MEDIUM }, //NVIDIA; GeForce RTX 2060
	{ 0x10DE, 0x1F12, MEDIUM }, //NVIDIA; GeForce RTX 2060 with Max-Q Design
	{ 0x10DE, 0x1F14, HIGH }, //NVIDIA; NVIDIA GeForce RTX 2070
	{ 0x10DE, 0x1F15, MEDIUM }, //NVIDIA; GeForce RTX 2060
	{ 0x10DE, 0x1F36, MEDIUM }, //NVIDIA; Quadro RTX 3000
	{ 0x10DE, 0x1F47, HIGH }, //NVIDIA; NVIDIA GeForce RTX 2060 SUPER
	{ 0x10DE, 0x1F50, HIGH }, //NVIDIA; GeForce RTX 2070
	{ 0x10DE, 0x1F82, MEDIUM }, //NVIDIA; GeForce GTX 1650
	{ 0x10DE, 0x1F91, MEDIUM }, //NVIDIA; GeForce GTX 1650
	{ 0x10DE, 0x1F95, MEDIUM }, //NVIDIA; GeForce GTX 1650 Ti
	{ 0x10DE, 0x1F96, MEDIUM }, //NVIDIA; GeForce GTX 1650
	{ 0x10DE, 0x1F97, VERY_LOW }, //NVIDIA; NVIDIA GeForce MX450
	{ 0x10DE, 0x1F99, MEDIUM }, //NVIDIA; GeForce GTX 1650
	{ 0x10DE, 0x1F9C, VERY_LOW }, //NVIDIA; NVIDIA GeForce MX450
	{ 0x10DE, 0x1F9D, MEDIUM }, //NVIDIA; GeForce GTX 1650
	{ 0x10DE, 0x1F9F, LOW }, //NVIDIA; NVIDIA GeForce MX550
	{ 0x10DE, 0x1FB1, LOW }, //NVIDIA; NVIDIA T600
	{ 0x10DE, 0x1FB2, VERY_LOW }, //NVIDIA; NVIDIA T400
	{ 0x10DE, 0x1FB6, VERY_LOW }, //NVIDIA; NVIDIA T600 Laptop GPU
	{ 0x10DE, 0x1FB7, LOW }, //NVIDIA; NVIDIA T550 Laptop GPU
	{ 0x10DE, 0x1FB8, LOW }, //NVIDIA; NVIDIA Quadro T2000
	{ 0x10DE, 0x1FB9, LOW }, //NVIDIA; Quadro T1000
	{ 0x10DE, 0x1FBA, VERY_LOW }, //NVIDIA; NVIDIA T600 Laptop GPU
	{ 0x10DE, 0x1FBB, VERY_LOW }, //NVIDIA; NVIDIA T500
	{ 0x10DE, 0x1FBC, LOW }, //NVIDIA; NVIDIA T1200 Laptop GPU
	{ 0x10DE, 0x1FDD, MEDIUM }, //NVIDIA; NVIDIA GeForce GTX 1650
	{ 0x10DE, 0x1FF2, VERY_LOW }, //NVIDIA; NVIDIA T400 4GB
	{ 0x10DE, 0x2182, MEDIUM }, //NVIDIA; GeForce GTX 1660 Ti
	{ 0x10DE, 0x2184, MEDIUM }, //NVIDIA; GeForce GTX 1660
	{ 0x10DE, 0x2187, MEDIUM }, //NVIDIA; GeForce GTX 1650 SUPER
	{ 0x10DE, 0x2188, MEDIUM }, //NVIDIA; NVIDIA GeForce GTX 1650
	{ 0x10DE, 0x2191, MEDIUM }, //NVIDIA; GeForce GTX 1660 Ti
	{ 0x10DE, 0x2192, MEDIUM }, //NVIDIA; GeForce GTX 1650 Ti
	{ 0x10DE, 0x21C4, MEDIUM }, //NVIDIA; GeForce GTX 1660 SUPER
	{ 0x10DE, 0x2203, ULTRA }, //NVIDIA; NVIDIA GeForce RTX 3090 Ti
	{ 0x10DE, 0x2204, HIGH }, //NVIDIA; GeForce RTX 3090
	{ 0x10DE, 0x2206, HIGH }, //NVIDIA; GeForce RTX 3080
	{ 0x10DE, 0x2207, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3070 Ti
	{ 0x10DE, 0x2208, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3080 Ti
	{ 0x10DE, 0x220A, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3080
	{ 0x10DE, 0x2216, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3080
	{ 0x10DE, 0x2230, HIGH }, //NVIDIA; NVIDIA RTX A6000
	{ 0x10DE, 0x2231, HIGH }, //NVIDIA; NVIDIA RTX A5000
	{ 0x10DE, 0x2232, HIGH }, //NVIDIA; NVIDIA RTX A4500
	{ 0x10DE, 0x2237, HIGH }, //NVIDIA; NVIDIA A10G
	{ 0x10DE, 0x2420, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3080 Ti Laptop GPU
	{ 0x10DE, 0x2438, MEDIUM }, //NVIDIA; NVIDIA RTX A5500 Laptop GPU
	{ 0x10DE, 0x2460, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3080 Ti Laptop GPU
	{ 0x10DE, 0x2482, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3070 Ti
	{ 0x10DE, 0x2484, HIGH }, //NVIDIA; GeForce RTX 3070
	{ 0x10DE, 0x2486, HIGH }, //NVIDIA; GeForce RTX 3060 Ti
	{ 0x10DE, 0x2487, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3060
	{ 0x10DE, 0x2488, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3070
	{ 0x10DE, 0x2489, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3060 Ti
	{ 0x10DE, 0x249C, HIGH }, //NVIDIA; GeForce RTX 3080 Laptop GPU
	{ 0x10DE, 0x249D, MEDIUM }, //NVIDIA; GeForce RTX 3070 Laptop GPU
	{ 0x10DE, 0x24A0, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3070 Ti Laptop GPU
	{ 0x10DE, 0x24B0, HIGH }, //NVIDIA; NVIDIA RTX A4000
	{ 0x10DE, 0x24B6, MEDIUM }, //NVIDIA; NVIDIA RTX A5000 Laptop GPU
	{ 0x10DE, 0x24B8, MEDIUM }, //NVIDIA; NVIDIA RTX A3000 Laptop GPU
	{ 0x10DE, 0x24B9, MEDIUM }, //NVIDIA; NVIDIA RTX A3000 12GB Laptop GPU
	{ 0x10DE, 0x24C9, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3060 Ti
	{ 0x10DE, 0x24DC, HIGH }, //NVIDIA; GeForce RTX 3080 Laptop GPU
	{ 0x10DE, 0x24DD, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 3070 Laptop GPU
	{ 0x10DE, 0x24E0, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3070 Ti Laptop GPU
	{ 0x10DE, 0x2503, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3060
	{ 0x10DE, 0x2504, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3060
	{ 0x10DE, 0x2507, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3050
	{ 0x10DE, 0x2508, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 3050 OEM
	{ 0x10DE, 0x2520, MEDIUM }, //NVIDIA; GeForce RTX 3060 Laptop GPU
	{ 0x10DE, 0x2531, MEDIUM }, //NVIDIA; NVIDIA RTX A2000
	{ 0x10DE, 0x2544, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3060
	{ 0x10DE, 0x2560, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 3060 Laptop GPU
	{ 0x10DE, 0x2563, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 3050 Ti Laptop GPU
	{ 0x10DE, 0x2571, MEDIUM }, //NVIDIA; NVIDIA RTX A2000 12GB
	{ 0x10DE, 0x2582, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3050
	{ 0x10DE, 0x25A0, MEDIUM }, //NVIDIA; GeForce RTX 3050 Ti Laptop GPU
	{ 0x10DE, 0x25A2, MEDIUM }, //NVIDIA; GeForce RTX 3050 Laptop GPU
	{ 0x10DE, 0x25A5, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 3050 Laptop GPU
	{ 0x10DE, 0x25A9, HIGH }, //NVIDIA; NVIDIA GeForce RTX 2050
	{ 0x10DE, 0x25AA, LOW }, //NVIDIA; NVIDIA GeForce MX570 A
	{ 0x10DE, 0x25AC, HIGH }, //NVIDIA; NVIDIA GeForce RTX 3050 6GB Laptop GPU
	{ 0x10DE, 0x25AD, HIGH }, //NVIDIA; NVIDIA GeForce RTX 2050
	{ 0x10DE, 0x25B8, MEDIUM }, //NVIDIA; NVIDIA RTX A2000 Laptop GPU
	{ 0x10DE, 0x25B9, MEDIUM }, //NVIDIA; NVIDIA RTX A1000 Laptop GPU
	{ 0x10DE, 0x25BA, MEDIUM }, //NVIDIA; NVIDIA RTX A2000 8GB Laptop GPU
	{ 0x10DE, 0x25BB, MEDIUM }, //NVIDIA; NVIDIA RTX A500 Laptop GPU
	{ 0x10DE, 0x25BC, MEDIUM }, //NVIDIA; NVIDIA RTX A1000 6GB Laptop GPU
	{ 0x10DE, 0x25E0, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 3050 Ti Laptop GPU
	{ 0x10DE, 0x25E2, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 3050 Laptop GPU
	{ 0x10DE, 0x25EC, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 3050 6GB Laptop GPU
	{ 0x10DE, 0x2684, ULTRA }, //NVIDIA; NVIDIA GeForce RTX 4090
	{ 0x10DE, 0x2702, ULTRA }, //NVIDIA; NVIDIA GeForce RTX 4080 SUPER
	{ 0x10DE, 0x2704, ULTRA }, //NVIDIA; NVIDIA GeForce RTX 4080
	{ 0x10DE, 0x2705, ULTRA }, //NVIDIA; NVIDIA GeForce RTX 4070 Ti SUPER
	{ 0x10DE, 0x2730, HIGH }, //NVIDIA; NVIDIA RTX 5000 Ada Generation Laptop GPU
	{ 0x10DE, 0x2757, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4090 Laptop GPU
	{ 0x10DE, 0x2782, ULTRA }, //NVIDIA; NVIDIA GeForce RTX 4070 Ti
	{ 0x10DE, 0x2783, ULTRA }, //NVIDIA; NVIDIA GeForce RTX 4070 SUPER
	{ 0x10DE, 0x2786, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4070
	{ 0x10DE, 0x27A0, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4080 Laptop GPU
	{ 0x10DE, 0x27BB, HIGH }, //NVIDIA; NVIDIA RTX 3500 Ada Generation Laptop GPU
	{ 0x10DE, 0x27E0, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4080 Laptop GPU
	{ 0x10DE, 0x2803, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4060 Ti
	{ 0x10DE, 0x2805, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4060 Ti
	{ 0x10DE, 0x2820, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4070 Laptop GPU
	{ 0x10DE, 0x2860, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4070 Laptop GPU
	{ 0x10DE, 0x2882, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4060
	{ 0x10DE, 0x28A0, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4060 Laptop GPU
	{ 0x10DE, 0x28A1, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 4050 Laptop GPU
	{ 0x10DE, 0x28E0, HIGH }, //NVIDIA; NVIDIA GeForce RTX 4060 Laptop GPU
	{ 0x10DE, 0x28E1, MEDIUM }, //NVIDIA; NVIDIA GeForce RTX 4050 Laptop GPU
	{ 0x10DE, 0x67DF, VERY_LOW }, //NVIDIA; NVIDIA GeForce GTX 765M
	{ 0x10DE, 0xFC0, VERY_LOW }, //NVIDIA; GeForce GT 640
	{ 0x10DE, 0xFC1, VERY_LOW }, //NVIDIA; GeForce GT 640
	{ 0x10DE, 0xFC2, VERY_LOW }, //NVIDIA; GeForce GT 630
	{ 0x10DE, 0xFC6, VERY_LOW }, //NVIDIA; GeForce GT 740
	{ 0x10DE, 0xFC8, VERY_LOW }, //NVIDIA; GeForce GT 740
	{ 0x10DE, 0xFCD, VERY_LOW }, //NVIDIA; GeForce GT 755M
	{ 0x10DE, 0xFD1, VERY_LOW }, //NVIDIA; GeForce GT 650M
	{ 0x10DE, 0xFD2, VERY_LOW }, //NVIDIA; GeForce GT 640M
	{ 0x10DE, 0xFD3, VERY_LOW }, //NVIDIA; GeForce GT 640M LE
	{ 0x10DE, 0xFD4, VERY_LOW }, //NVIDIA; GeForce GTX 660M
	{ 0x10DE, 0xFD9, VERY_LOW }, //NVIDIA; GeForce GT 645M
	{ 0x10DE, 0xFDF, VERY_LOW }, //NVIDIA; GeForce GT 740M
	{ 0x10DE, 0xFE1, VERY_LOW }, //NVIDIA; GeForce GT 730M
	{ 0x10DE, 0xFE3, VERY_LOW }, //NVIDIA; GeForce GT 745M
	{ 0x10DE, 0xFE4, VERY_LOW }, //NVIDIA; GeForce GT 750M
	{ 0x10DE, 0xFE9, VERY_LOW }, //NVIDIA; GeForce GT 750M
	{ 0x10DE, 0xFF3, VERY_LOW }, //NVIDIA; Quadro K420
	{ 0x10DE, 0xFF6, VERY_LOW }, //NVIDIA; Quadro K1100M
	{ 0x10DE, 0xFFA, VERY_LOW }, //NVIDIA; Quadro K600
	{ 0x10DE, 0xFFB, VERY_LOW }, //NVIDIA; Quadro K2000M
	{ 0x10DE, 0xFFC, VERY_LOW }, //NVIDIA; Quadro K1000M
	{ 0x10DE, 0xFFE, VERY_LOW }, //NVIDIA; K2000
	{ 0x10DE, 0xFFF, VERY_LOW }, //NVIDIA; NVIDIA Quadro 410

	// #qualcomm
	{ 0x5143, 0x6030500, NONE }, //Qualcomm; Adreno 7c+ Gen 3
	{ 0x5143, 0x6080001, NONE }, //Qualcomm; Qualcomm(R) Adreno(TM) 640 GPU
	{ 0x5143, 0x6090000, NONE }, //Qualcomm; Adreno (TM) 690
	{ 0x5143, 0x7030002, NONE }, //Qualcomm; Turnip Adreno (TM) 725
};
