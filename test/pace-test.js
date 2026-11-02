// Run: TZ=Asia/Jakarta node test/pace-test.js
const fs = require("fs");
const assert = require("assert");
const src = fs.readFileSync(`${__dirname}/../package/contents/ui/pace.js`, "utf8").replace(".pragma library", "");
const { pace } = new Function(`${src}; return { pace };`)();

// Week from Sun Nov 1 01:00 to Sun Nov 8 01:00, 168 hours:
// work = Sun 9 + Mon–Fri 90 + Sat 9 = 108, free = 60, given up front. Minus 10 points.
const reset = new Date(2026, 10, 8, 1).getTime();
const at = (d, h) => new Date(2026, 10, d, h).getTime();

assert.strictEqual(pace(reset, at(1, 1)), 26);            // free share up front: 60/168 - 10
assert.strictEqual(pace(reset, at(1, 6)), 26);            // night adds nothing more
assert.strictEqual(pace(reset, at(2, 6)), 31);            // + Sunday half: 69/168 - 10
assert.strictEqual(pace(reset, at(3, 0)), 42);            // + Monday: 87/168 - 10
assert.strictEqual(pace(reset, at(7, 0)), 85);            // + Mon–Fri: 159/168 - 10
assert.strictEqual(pace(reset, reset), 90);               // 10% buffer left
assert.strictEqual(pace(reset, reset + 3600000), 90);     // after reset, clamped
console.log("pace ok");
