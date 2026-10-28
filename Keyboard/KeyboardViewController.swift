import Combine
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardModel()
    private var heightConstraint: NSLayoutConstraint?
    private var watch: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        model.insert = { [weak self] in self?.textDocumentProxy.insertText($0) }
        model.deleteBackward = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        model.contextBefore = { [weak self] in self?.textDocumentProxy.documentContextBeforeInput }
        model.nextKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        model.dismiss = { [weak self] in self?.dismissKeyboard() }

        let host = UIHostingController(rootView: KeyboardView(model: model))
        host.view.backgroundColor = .clear
        host.sizingOptions = []
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        let h = view.heightAnchor.constraint(equalToConstant: KeyboardView.height(translateOn: model.translateOn))
        h.priority = .init(999)
        h.isActive = true
        heightConstraint = h

        watch = model.$translateOn.sink { [weak self] on in
            self?.heightConstraint?.constant = KeyboardView.height(translateOn: on)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.hasFullAccess = hasFullAccess
        model.needsGlobe = needsInputModeSwitchKey
        model.refreshAvailability()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        model.needsGlobe = needsInputModeSwitchKey
    }
}
