import ComposableArchitecture
import Foundation
import SwiftUI

public struct Coordinator {
  private let _coordinate: (CoordinatorAction) -> Void
  private let _buildRoute: (AnyRoute) -> Coordinated?
  private let _parse: (URL) -> AnyRoute?

  public init(
    coordinate: @escaping (CoordinatorAction) -> Void,
    buildRoute: @escaping (AnyRoute) -> Coordinated?,
    parse: @escaping (URL) -> AnyRoute?
  ) {
    self._coordinate = coordinate
    self._buildRoute = buildRoute
    self._parse = parse
  }

  public func coordinate(_ action: CoordinatorAction) {
    _coordinate(action)
  }

  func build(_ route: AnyRoute) -> Coordinated? {
    _buildRoute(route)
  }

  func parse(_ url: URL) -> AnyRoute? {
    _parse(url)
  }
}

extension Coordinator {
  static func combine(
    _ coordinators: [Coordinator]
  ) -> Coordinator {
    let buildRoute = { route -> Coordinated? in
      return coordinators
        .compactMap { $0.build(route) }
        .first
    }

    return Coordinator(
      coordinate: { action in
        coordinators.forEach { $0.coordinate(action) }
      },
      buildRoute: { route in
        buildRoute(route).map {
          var next = $0
          next.buildRoute = buildRoute
          return next
        }
      },
      parse: { url in
        coordinators
          .compactMap { $0.parse(url) }
          .first
      }
    )
  }

  static func combine(
    _ coordinators: Coordinator...
  ) -> Coordinator {
    combine(coordinators)
  }
}