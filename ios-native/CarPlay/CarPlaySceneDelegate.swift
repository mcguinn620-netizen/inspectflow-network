#if canImport(CarPlay)
import CarPlay

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private let coordinator = CarPlayNavigationCoordinator()

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        coordinator.connect(interfaceController: interfaceController)
    }
}
#endif
