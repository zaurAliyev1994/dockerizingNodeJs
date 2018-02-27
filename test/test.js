var calc = require('../calc.js');

test('Calculator Tests: add', () => {
    expect(calc.add(1, 2)).toBe(3);
});

test('Calculator Tests: mul', () => {
    expect(calc.mul(1, 2)).toBe(2);
});