<p align="center">
  <img src="./Documentation/logo.png" width="15%" align-content: center/>
</p>
<h3 align="center">Composable Navigator</h2>
<h3 align="center">
  An open source library for building deep-linkable SwiftUI applications with composition, testing and ergonomics in mind
</h3>
<p align="center"><a title="GitHub Actions" target="_blank" href="https://github.com/Bahn-X/swift-composable-navigator/workflows/test/badge.svg">
		<img src="https://github.com/Bahn-X/swift-composable-navigator/workflows/test/badge.svg"
					alt="test status"></p>
<hr class="rounded">

- [Vanilla SwiftUI navigation](#vanilla-swiftui-navigation)
- [Challenges](#challenges)
- [Why should I use ComposableNavigator?](#why-should-i-use-composablenavigator)
- [Core components](#core-components)
  - [Navigation Path](#navigation-path)
  - [Navigator](#navigator)
  - [NavigationTree](#navigationtree)
- [Vanilla SwiftUI + ComposableNavigator](#vanilla-swiftui--composablenavigator)
- [Integrating ComposableNavigator](#integrating-composablenavigator)
- [Deeplinking](#deeplinking)
- [Dependency injection](#dependency-injection)
- [Installation](#installation)
  - [Swift Package](#swift-package)
  - [Xcode](#xcode)
- [Example application](#example-application)
- [Documentation](#documentation)
- [Contribution](#contribution)
- [License](#license)

<hr class="rounded">

## Vanilla SwiftUI navigation
A typical, vanilla SwiftUI application manages its navigation state (i.e. is a sheet or a push active) either directly in its Views or in ObservableObjects.

Let's take a look at a simplified example in which we keep all navigation state locally in the view:

```swift
struct HomeView: View {
  @State var isSheetActive: Bool = false
  @State var isDetailShown: Bool = false

  var body: some View {
    VStack {
      NavigationLink(
        destination: DetailView(),
        isActive: $isDetailShown,
        label: {
          Text("Go to detail view")
        }
      )

      Button("Go to settings") {
        isSheetActive = true
      }
    }
    .sheet(
      isPresented: $isSheetActive,
      content: {
        SettingsView()
      }
    )
  }
}
```

## Challenges
### How do we test that when the user taps the navigation link, we move to the DetailView and not the SettingsView?<!-- omit in toc -->
As `isSheetActive` and `isDetailShown` are kept locally in the View and their values are directly mutated by a binding, we cannot test any navigation logic unless we write UI tests or implement custom bindings that call functions in an ObservableObject mutating the navigation state.

### What if I want to show a second sheet with different content?<!-- omit in toc -->
We can either introduce an additional `isOtherSheetActive` variable or a hashable enum `HomeSheet: Hashable` and keep track of the active sheet in a `activeSheet: HomeSheet?` variable.

### What happens if both `isSheetActive` and `isDetailShown` are true?<!-- omit in toc -->
The sheet is shown on top of the current content, meaning that we can end up in a situation in which the settings sheet is presented on top of a detail view.

### How do we programmatically navigate after a network request has finished?<!-- omit in toc -->
To programmatically navigate, we need to keep our navigation state in an ObservableObject that performs asynchronous actions such as network requests. When the request succeeds, we set `isDetailShown` or `isSheetActive` to true. We also need to make sure that all other navigation related variables are set to false/nil or else we might end up with an unexpected navigation tree.

### What happens if the NavigationLink is contained in a lazily loaded List view and the view we want to navigate to has not yet been initialized?<!-- omit in toc -->
The answer to this one is simple: SwiftUI will not navigate. Imagine, we have a list of hundreds of entries that the user can scroll through. If we want to programmatically navigate to an entry detail view, the 'cell' containing the NavigationLink needs to be in memory or else the navigation will not be performed.

### NavigationLinks do not navigate when I click them<!-- omit in toc -->
In order to make NavigationLinks work in our view, we need to wrap our view in a NavigationView.

So, at which point in the view hierarchy do we wrap our content in a NavigationView? As wrapping content in a NavigationView twice will lead to two navigation bars, we probably want to avoid having to multiple nested NavigationViews.

### Shallow Deeplinking<!-- omit in toc -->
Vanilla SwiftUI only supports shallow deeplinking, meaning that we can navigate from the ExampleView to the DetailView by setting the initial value of `isDetailShown` to true. However, we cannot navigate further down into our application as SwiftUI seems to ignore initial values in pushed/presented views.

## Why should I use ComposableNavigator?
**ComposableNavigator** lifts the burden of manually managing navigation state off your shoulders and allows to navigate through applications along navigation paths. **ComposableNavigator** takes care of embedding your views in NavigationViews, where needed, and always builds a valid view hierarchy. On top of that, **ComposableNavigator** unlocks advanced navigation patterns like wildcards and conditional navigation paths.

## Core components
**ComposableNavigator** is built on three core components: the navigation tree, the current navigation path, and the navigator.

### Navigation Path
The navigation path describes the order of visible screens in the  application. It is a first-class representation of the `<url-path>` defined in [RFC1738](https://tools.ietf.org/html/rfc1738#section-3.1). A navigation path consists of identified screens.

#### Screen<!-- omit in toc -->
A Screen is a first-class representation of the information needed to build a particular view. Screen objects identify the navigation path element and can contain arguments like IDs, initial values, and flags. `detail?id=0` directly translates to `DetailScreen(id: 0)`.

Screens define how they are presented. This decouples presentation logic from business logic, as showing a sheet and pushing a view are performed by invoking the same `go(to:, on:)` function. Changing a screen's (default) presentation style is a single line change. Currently, sheet and push presentation styles are supported.

### Navigator
The navigator manages the application's current navigation path and allows mutations on it. The navigator acts as an interface to the underlying data source. The navigator object is accessible via the view environment.

Navigators allow programmatic navigation and can be injected where needed, even into ViewModels.

### NavigationTree
The **ComposableNavigator** is based on the concept of `PathBuilder` composition in form of a `NavigationTree`. A `NavigationTree`  composes `PathBuilder`s to describe all valid navigation paths in an application. That also means that all screens in our application are accessible via a pre-defined navigation path.

Let's look at an example `NavigationTree`:

```swift
struct AppNavigationTree: NavigationTree {
  let homeViewModel: HomeViewModel
  let detailViewModel: DetailViewModel
  let settingsViewModel: SettingsViewModel

  var builder: some PathBuilder {
    Screen(
      HomeScreen.self,
      content: {
        HomeView(viewModel: homeViewModel)
      },
      nesting: {
        DetailScreen.Builder(viewModel: detailViewModel),
        SettingsScreen.Builder(viewModel: settingsViewModel)
      }
    )
  }
}
```

![Example Tree](./Documentation/readmeExample.svg)

Based on `AppNavigationTree`, the following navigation paths are valid:
```
  /home
  /home/detail?id=0
  /home/settings
```

More information on the `NavigationTree` and how to compose `PathBuilder`s can be found [here](https://github.com/Bahn-X/swift-composable-navigator/wiki/NavigationTree).

## Vanilla SwiftUI + ComposableNavigator
Let's go back to our vanilla SwiftUI home view and enhance it using the ComposableNavigator.

```swift
import ComposableNavigator

struct HomeView: View {
  @Environment(\.navigator) var navigator
  @Environment(\.currentScreenID) var currentScreenID

  var body: some View {
    VStack {
      Button(
        action: goToDetail,
        label: { Text("Show detail screen for 0") }
      )

      Button(
        action: goToSettings,
        label: { Text("Go to settings screen") }
      )
    }
  }

  func goToDetail() {
    navigator.go(
      to: DetailScreen(detailID: "0"),
      on: currentScreenID
    )
  }

  func goToSettings() {
    navigator.go(
      to: SettingsScreen(),
      on: HomeScreen()
    )
  }
}
```

We can now inject the `Navigator` and `currentScreenID` in our tests and cover calls to goToDetail / goToSettings on an ExampleView instance in unit tests.

## Integrating ComposableNavigator
```swift
import ComposableNavigator
import SwiftUI

struct AppNavigationTree: NavigationTree {
  let homeViewModel: HomeViewModel
  let detailViewModel: DetailViewModel
  let settingsViewModel: SettingsViewModel

  var builder: some PathBuilder {
    Screen(
      HomeScreen.self,
      content: {
        HomeView(viewModel: homeViewModel)
      },
      nesting: {
        DetailScreen.Builder(viewModel: detailViewModel),
        SettingsScreen.Builder(viewModel: settingsViewModel)
      }
    )
  }
}

@main
struct ExampleApp: App {
  let dataSource = Navigator.Datasource(root: HomeScreen())

  var body: some Scene {
    WindowGroup {
      Root(
        dataSource: dataSource,
        pathBuilder: AppNavigationTree(...)
      )
    }
  }
}
```

## Deeplinking
As **ComposableNavigator** builds the view hierarchy based on navigation paths, it is the ideal companion to implement deeplinking. Deeplinks come in different forms and shapes, however **ComposableNavigator** abstracts it into a first-class representation in form of the `Deeplink` type. The **ComposableDeeplinking** library that is part of the **ComposableNavigator** contains a couple of helper types that allow easily replace the current navigation path with a new navigation path based on a `Deeplink` by defining a `DeeplinkHandler` and a composable `DeeplinkParser`.

More information on deeplinking and how to implement it in your own application can be found [here](https://github.com/Bahn-X/swift-composable-navigator/wiki/Deeplinking).

## Dependency injection
**ComposableNavigator** was inspired by [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) and its approach to Reducer composition, dependency injection and state management. As all view building closures flow together in one central place, the app navigation tree, ComposableNavigator gives you full control over dependency injection. Currently, the helper package **ComposableNavigatorTCA** is part of this repository and the main package therefore has a dependency on TCA. This will change in the future when **ComposableNavigatorTCA** gets [extracted into its own repository](https://github.com/Bahn-X/swift-composable-navigator/issues/12).

## Installation
**ComposableNavigator** supports Swift Package Manager and contains two products, *ComposableNavigator* and *ComposableDeeplinking*.

### Swift Package
If you want to add **ComposableNavigator** to your Swift packages, add it as a dependency to your `Package.swift`.

```swift
dependencies: [
    .package(
      name: "ComposableNavigator",
      url: "https://github.com/Bahn-X/swift-composable-navigator.git",
      from: "0.1.0"
    )
],
targets: [
    .target(
        name: "MyAwesomePackage",
        dependencies: [
            .product(name: "ComposableNavigator", package: "ComposableNavigator"),
            .product(name: "ComposableDeeplinking", package: "ComposableNavigator")
        ]
    ),
]
```

### Xcode
<p align="center"><img src="./Documentation/xc.png" width="70%"></img></p>

You can add **ComposableNavigator** to your project via Xcode. Open your project, click on **File → Swift Packages → Add Package Dependency…**, enter the repository url (https://github.com/Bahn-X/swift-composable-navigator.git) and add the package products to your app target.

## Example application
<p align="center"><img src="./Documentation/exampleapp.gif" width="40%"></img></p>

The **ComposableNavigator** repository contains [an example application](./Example) showcasing a wide range of library features and path builder patterns that are also applicable in your application. The example app is based on **ComposableNavigator** + **TCA** but also shows how to navigate via the navigator contained in a view's environment as you could do it in a Vanilla SwiftUI application.

The Example application contains a UI test suite that is run on every pull request. In that way, we can make sure that, even if SwiftUI changes under the hood, **ComposableNavigator** behaves as expected.

## Documentation
The latest ComposableNavigator documentation is available in the [wiki](https://github.com/Bahn-X/swift-composable-navigator/wiki).

## Contribution
The contribution process for this repository is described in [CONTRIBUTING](./CONTRIBUTING.md). We welcome contribution and look forward to your ideas.

## License
This library is released under the MIT license. See [LICENSE](LICENSE) for details.
