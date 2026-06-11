//
//  ShareViewController.swift
//  InspectFlowShareExtension
//
//  Created by Matt McGuinn on 6/11/26.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        processInput()
    }

    private func processInput() {

        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem
        else {
            complete()
            return
        }

        guard let providers = item.attachments else {
            complete()
            return
        }

        for provider in providers {

            if provider.hasItemConformingToTypeIdentifier(
                UTType.url.identifier
            ) {

                handleURL(provider)
                return
            }

            if provider.hasItemConformingToTypeIdentifier(
                UTType.pdf.identifier
            ) {

                handlePDF(provider)
                return
            }
        }

        complete()
    }

    private func handleURL(
        _ provider: NSItemProvider
    ) {

        provider.loadItem(
            forTypeIdentifier: UTType.url.identifier,
            options: nil
        ) { item, error in

            guard let url = item as? URL else {
                self.complete()
                return
            }

            let payload = SharedImport(
                id: UUID(),
                kind: .webLink,
                title: url.absoluteString,
                url: url.absoluteString,
                localFile: nil,
                createdAt: Date()
            )

            self.save(payload)
        }
    }

    private func handlePDF(
        _ provider: NSItemProvider
    ) {

        provider.loadFileRepresentation(
            forTypeIdentifier: UTType.pdf.identifier
        ) { url, error in

            guard let url else {
                self.complete()
                return
            }

            let payload = SharedImport(
                id: UUID(),
                kind: .pdf,
                title: url.lastPathComponent,
                url: nil,
                localFile: url.path,
                createdAt: Date()
            )

            self.save(payload)
        }
    }

    private func save(
        _ payload: SharedImport
    ) {

        let defaults = UserDefaults(
            suiteName: "group.com.inspectflow.shared"
        )

        var items: [Data] =
            defaults?.array(
                forKey: "sharedImports"
            ) as? [Data] ?? []

        if let data = try? JSONEncoder().encode(payload) {
            items.append(data)
        }

        defaults?.set(
            items,
            forKey: "sharedImports"
        )

        DispatchQueue.main.async {
            self.launchMainApp()
        }
    }

    private func launchMainApp() {

        let url = URL(
            string: "inspectflow://imports"
        )!

        var responder: UIResponder? = self

        while responder != nil {

            if let application =
                responder as? UIApplication {

                application.open(url)
                break
            }

            responder = responder?.next
        }

        complete()
    }

    private func complete() {

        extensionContext?.completeRequest(
            returningItems: nil
        )
    }
}
