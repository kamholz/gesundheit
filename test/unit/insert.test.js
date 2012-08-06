g = require('../../lib')
require('tap').test('INSERT queries', function (t) {
  t.throws(function(){ g.insert('t1') }, "constructor throws if no fields given")
  q = g.insert('t1', ['a', 'b'])
  t.throws(function(){ q.addRow([1, 2, 3]) },
           "errors when adding a row of the wrong length")

  t.deepEqual(
    q.copy().addRow({a: 2, b: 50}).compile(),
    ["INSERT INTO t1 (a, b) VALUES (?, ?)", [2, 50]],
		"can add a single row")

  t.deepEqual(
    q.copy().addRows([1,2], [3,4]).compile(),
    ["INSERT INTO t1 (a, b) VALUES (?, ?), (?, ?)", [1,2,3,4]],
		"can add multiple rows")

  t.deepEqual(
    q.copy().addRow({a: 1, c: 3, d: 99}).compile(),
    ["INSERT INTO t1 (a, b) VALUES (?, DEFAULT)", [1]],
		"extracts the correct fields from an object")
			
  t.deepEqual(
    q.copy().from(g.select('t2', ['x', 'y']).where({x: {gt: 50}})).compile(),
    ["INSERT INTO t1 (a, b) SELECT t2.x, t2.y FROM t2 WHERE t2.x > ?", [50]],
    "can source from a SELECT query"
  )
  t.end()
})