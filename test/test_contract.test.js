'use strict'

const t = require('tap');
const { test } = t;
const path = require('path');

const { SuiTestScenario } = require('suidouble');

let testScenario = null;

test('initialization', async t => {
    testScenario = new SuiTestScenario({
        path: path.join(__dirname, '../move/'),
        debug: false,
    });

    await testScenario.begin('admin');
    await testScenario.init();

    t.equal(testScenario.currentAs, 'admin');
});

test('finishing the test scenario', async t => {
    await testScenario.end();
});
