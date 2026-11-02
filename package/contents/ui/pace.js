.pragma library

// Safe pace: the share of the week's usable time gone by, in local time.
// 00:00–06:00 counts nothing, Saturday and Sunday count half.
const HOUR = 3600000;

function dayWeight(day) {
    return day.getDay() === 0 || day.getDay() === 6 ? 0.5 : 1;
}

// Weighted milliseconds between a and b.
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
    const start = resetMs - 7 * 24 * HOUR;
    const t = Math.min(Math.max(nowMs, start), resetMs);
    return Math.round(100 * weighted(start, t) / weighted(start, resetMs));
}
