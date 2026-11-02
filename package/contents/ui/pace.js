.pragma library

// Safe pace, in local time. Time you won't work (00:00–06:00, and half of
// Saturday and Sunday) is free: its share of the week is given up front.
// Work time adds the rest as it passes. 10% of the quota stays as a buffer.
const HOUR = 3600000;
const WEEK = 7 * 24 * HOUR;
const BUFFER = 0.1;

function dayWeight(day) {
    return day.getDay() === 0 || day.getDay() === 6 ? 0.5 : 1;
}

// Work milliseconds between a and b.
function weighted(a, b) {
    let sum = 0;
    const day = new Date(a);
    day.setHours(0, 0, 0, 0);
    while (day.getTime() < b) {
        const next = new Date(day);
        next.setDate(day.getDate() + 1);
        const from = Math.max(a, day.getTime() + 6 * HOUR);
        const to = Math.min(b, next.getTime());
        if (to > from)
            sum += (to - from) * dayWeight(day);
        day.setTime(next.getTime());
    }
    return sum;
}

// Percent of the week ending at resetMs that is used up by nowMs.
function pace(resetMs, nowMs) {
    const start = resetMs - WEEK;
    const t = Math.min(Math.max(nowMs, start), resetMs);
    const free = WEEK - weighted(start, resetMs);
    return Math.round(100 * (1 - BUFFER) * (free + weighted(start, t)) / WEEK);
}
