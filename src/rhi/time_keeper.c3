// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;

const ulong UPDATES_PER_S @private = 60;
const ulong MAX_ACCUMULATED_UPDATES @private = 8;
const ulong[4] SNAP_FRAME_RATES @private = { UPDATES_PER_S, 30, 120, 144 };
const ulong TICKS_PER_TOCK @private = 720; // Least common multiple of 'SNAP_FRAME_RATES'
const ulong SNAP_TOLERANCE_US @private = 200;
const ulong US_PER_S @private = 1_000_000;

// Fixed-timestep accumulator that snaps frame deltas close to common refresh
// rates, so a 60 Hz display produces exactly one update per frame.
struct TimeKeeper
{
	ulong tocks_per_s;
	ulong accumulated_ticks;
	// Odin's `Maybe(u64)`: `previous_timestamp` is valid only if `has_previous`.
	ulong previous_timestamp;
	bool has_previous;
}

fn ulong sat_mul(ulong a, ulong b) @private @inline
{
	return a.overflow_mul(b) ?? ulong::max;
}

fn ulong sat_add(ulong a, ulong b) @private @inline
{
	return a.overflow_add(b) ?? ulong::max;
}

fn bool TimeKeeper.consume(&self)
{
	ulong ticks_per_s = self.tocks_per_s * TICKS_PER_TOCK;
	ulong ticks_per_update = ticks_per_s / UPDATES_PER_S;
	if (self.accumulated_ticks >= ticks_per_update)
	{
		self.accumulated_ticks -= ticks_per_update;
		return true;
	}
	return false;
}

fn void TimeKeeper.produce(&self, ulong current_timestamp)
{
	if (self.has_previous)
	{
		ulong ticks_per_s = self.tocks_per_s * TICKS_PER_TOCK;
		ulong elapsed_ticks = sat_mul(current_timestamp - self.previous_timestamp, TICKS_PER_TOCK);
		ulong snapped_elapsed_ticks = elapsed_ticks;
		foreach (snap_frame_rate : SNAP_FRAME_RATES)
		{
			ulong target_ticks = ticks_per_s / snap_frame_rate;
			ulong abs_diff = max(elapsed_ticks, target_ticks) - min(elapsed_ticks, target_ticks);
			if (sat_mul(abs_diff, US_PER_S) <= sat_mul(SNAP_TOLERANCE_US, ticks_per_s))
			{
				snapped_elapsed_ticks = target_ticks;
				break;
			}
		}
		ulong ticks_per_update = ticks_per_s / UPDATES_PER_S;
		ulong max_accumulated_ticks = MAX_ACCUMULATED_UPDATES * ticks_per_update;
		self.accumulated_ticks = min(sat_add(self.accumulated_ticks, snapped_elapsed_ticks), max_accumulated_ticks);
	}
	self.previous_timestamp = current_timestamp;
	self.has_previous = true;
}
