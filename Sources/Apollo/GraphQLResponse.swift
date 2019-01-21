/// Represents a GraphQL response received from a server.
public final class GraphQLResponse<Operation: GraphQLOperation> {
  public let operation: Operation
  public let body: JSONObject

  public init(operation: Operation, body: JSONObject) {
    self.operation = operation
    self.body = body
  }
  
  func parseResult(cacheKeyForObject: CacheKeyForObject? = nil) throws -> Promise<(GraphQLResult<Operation.Data>, RecordSet?)>  {
    if let errorsEntry = body["errors"] as? [JSONObject] {
      let errors = errorsEntry.map(GraphQLError.init)
      return Promise(fulfilled: (GraphQLResult(data: nil, errors: errors, source: .server, dependentKeys: nil), nil))
    }
    
    if let dataEntry = body["data"] as? JSONObject {
      let executor = GraphQLExecutor { object, info in
        return .result(.success(object[info.responseKeyForField]))
      }
      
      executor.cacheKeyForObject = cacheKeyForObject
      
      let mapper = GraphQLSelectionSetMapper<Operation.Data>()
      let normalizer = GraphQLResultNormalizer()
      let dependencyTracker = GraphQLDependencyTracker()
      
      return firstly {
        try executor.execute(selections: Operation.Data.selections, on: dataEntry, withKey: rootCacheKey(for: operation), variables: operation.variables, accumulator: zip(mapper, normalizer, dependencyTracker))
        }.map { (data, records, dependentKeys) in
          (GraphQLResult(data: data, errors: nil, source: .server, dependentKeys: dependentKeys), records)
      }
    } else {
      return Promise(fulfilled: (GraphQLResult(data: nil, errors: nil, source: .server, dependentKeys: nil), nil))
    }
  }
}
