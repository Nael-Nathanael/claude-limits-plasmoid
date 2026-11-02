// Run: TZ=Asia/Jakarta node test/pace-test.js
const fs = require("fs");
const assert = require("assert");
const src = fs.readFileSync(`${__dirname}/../package/contents/ui/pace.js`, "utf8").replace(".pragma library", "");
const { pace } = new Function(`${src}; return { pace };`)();

// Week from Sun Nov 1 01:00 to Sun Nov 8 01:00: Sun 9 + Mon–Fri 90 + Sat 9 = 108 weighted hours.
const reset = new Date(2026, 10, 8, 1).getTime();
const at = (d, h) => new Date(2026, 10, d, h).getTime();

assert.strictEqual(pace(reset, at(1, 1)), 0);
assert.strictEqual(pace(reset, at(1, 6)), 0);             // night counts nothing
assert.strictEqual(pace(reset, at(2, 6)), 8);             // Sunday half: 9/108
assert.strictEqual(pace(reset, at(3, 0)), 25);            // + Monday: 27/108
assert.strictEqual(pace(reset, at(7, 0)), 92);            // + Mon–Fri: 99/108
assert.strictEqual(pace(reset, reset), 100);
assert.strictEqual(pace(reset, reset + 3600000), 100);    // after reset, clamped
console.log("pace ok");
