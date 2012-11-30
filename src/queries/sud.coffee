BaseQuery = require './base'
nodes = require '../nodes'
fluidize = require '../fluid'
{And, Or, OrderBy, CONST_NODES} = nodes

module.exports = class SUDQuery extends BaseQuery
  ###
  SUDQuery is the base class for SELECT, UPDATE, and DELETE queries. It adds
  logic to :class:`queries/base::BaseQuery` for dealing with WHERE clauses and
  ordering.
  ###

  where: (alias, predicate) ->
    ###
    Add a WHERE clause to the query. Can optionally take a table/alias name as the
    first parameter, otherwise the clause is added using the last table added to
    the query.

    The where clause itself can be a comparison node, such as those produced by
    the :class:`nodes::ComparableMixin` methods::

      q.where(q.project('table','field1').eq(42))
      q.where(q.project('table','field2').gt(42))

    ... Or an object literal where each key is a field name (or field name
    alias) and each value is a constraint::

      q.where('table', {field1: 42, field2: {gt: 42}})

    Constraints values can also be other projected fields::

      p = q.project.bind(q, 'table')
      q.where('table', p('field1').gt(p('field2')))

    ###
    if predicate?
      rel = @q.relations.get alias
      unknown 'table', alias unless rel?
    else
      predicate = alias
      rel = @defaultRel()

    if predicate.constructor != Object
      return @q.where.addNode predicate

    @q.where.addNode(node) for node in @makeClauses(rel, predicate)

  or: (args...) ->
    ###
    Add one or more WHERE clauses, all joined by the OR operator.

    If any argument is an object literal that creates more than one clause on
    it's own those clauses will be joined with AND operators. So for example::

      select('t').or({a: 1}, {b: 2, c: 3})

    Will generate the SQL statement::

      SELECT * FROM t WHERE (t.a = 1 OR (t.b = 2 AND t.c = 3))

    ###
    rel = @defaultRel()
    clauses = []
    orClause = new Or
    for arg in args
      andClauses = @makeClauses rel, arg
      if andClauses.length > 1
        orClause.addNode(new And(andClauses))
      else if andClauses.length is 1
        orClause.addNode(andClauses[0])
    @where orClause

  makeClauses: (rel, constraint) ->
    clauses = []
    for field, predicate of constraint
      if predicate is null
        clauses.push rel.project(field).compare 'IS', CONST_NODES.NULL
      else if predicate.constructor is Object
        for op, val of predicate
          clauses.push rel.project(field).compare op, val
      else
        clauses.push rel.project(field).eq predicate
    clauses

  order: (args...) ->
    ###
    Add an ORDER BY to the query. Currently this *always* uses the "active"
    table of the query. (See :meth:`queries/select::SelectQuery.from`)

    Each ordering can either be a string, in which case it must be a valid-ish
    SQL snippet like 'some_field DESC', (the field name and direction will still
    be normalized) or an object, in which case each key will be treated as a
    field and each value as a direction.
    ###
    rel = @defaultRel()
    orderings = []
    for orderBy in args
      switch orderBy.constructor
        when String
          orderings.push orderBy.split ' '
        when OrderBy
          @q.orderBy.addNode orderBy
        when Object
          for name, dir of orderBy
            orderings.push [name, dir]
        else
          throw new Error "Can't turn #{orderBy} into an OrderBy object"

    for [field, direction] in orderings
      direction = switch (direction || '').toLowerCase()
        when 'asc',  'ascending'  then 'ASC'
        when 'desc', 'descending' then 'DESC'
        when '' then ''
        else throw new Error "Unsupported ordering direction #{direction}"
      @q.orderBy.addNode new OrderBy(rel.project(field), direction)

  limit: (l) ->
    ### Set the LIMIT on this query ###
    @q.limit.value = l

  offset: (l) ->
    ### Set the OFFSET of this query ###
    @q.offset.value = l

  defaultRel: ->
    @q.relations.active

fluidize SUDQuery, 'where', 'or', 'limit', 'offset', 'order'

# A helper for throwing Errors
unknown = (type, val) -> throw new Error "Unknown #{type}: #{val}"
