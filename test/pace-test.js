// Run: TZ=Asia/Jakarta node test/pace-test.js
const fs = require("fs");
const assert = require("assert");
const src = fs.readFileSync(`${__dirname}/../package/contents/ui/pace.js`, "utf8").replace(".pragma library", "");
const { pace } = new Function(`${src}; return { pace };`)();

// Week from Sun Nov 1 01:00 to Sun Nov 8 01:00, 168 hours:
// work = Sun 9 + Mon–Fri 90 + Sat 9 = 108, free = 60, given up front. Scaled by 0.9.
const reset = new Date(2026, 10, 8, 1).getTime();
const at = (d, h) => new Date(2026, 10, d, h).getTime();

assert.strictEqual(pace(reset, at(1, 1)), 32);            // free share up front: 0.9 * 60/168
assert.strictEqual(pace(reset, at(1, 6)), 32);            // night adds nothing more
assert.strictEqual(pace(reset, at(2, 6)), 37);            // + Sunday half: 0.9 * 69/168
assert.strictEqual(pace(reset, at(3, 0)), 47);            // + Monday: 0.9 * 87/168
assert.strictEqual(pace(reset, at(7, 0)), 85);            // + Mon–Fri: 0.9 * 159/168
assert.strictEqual(pace(reset, reset), 90);               // 10% buffer left
assert.strictEqual(pace(reset, reset + 3600000), 90);     // after reset, clamped
console.log("pace ok");
