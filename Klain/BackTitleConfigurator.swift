import SwiftUI

// Keep UIKit's native back button and interactive edge-swipe recognizer.
struct BackTitleConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.updateTitle() }
    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); updateTitle() }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); updateTitle() }
        func updateTitle() {
            guard let navigation = navigationController, navigation.viewControllers.count > 1 else { return }
            let previous = navigation.viewControllers[navigation.viewControllers.count - 2]
            previous.navigationItem.backButtonTitle = "Назад"
            previous.navigationItem.backButtonDisplayMode = .default
        }
    }
}
