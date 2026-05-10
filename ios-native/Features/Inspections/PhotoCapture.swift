import SwiftUI
import UIKit

/// Lightweight camera/photo-library picker that returns a single JPEG `Data`.
/// `UIImagePickerController` is Xcode 14 / Playgrounds friendly (avoids PhotosUI restrictions).
struct PhotoCapture: UIViewControllerRepresentable {
    enum Source { case camera, library }
    let source: Source
    let onPicked: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = (source == .camera && UIImagePickerController.isSourceTypeAvailable(.camera))
            ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoCapture
        init(_ parent: PhotoCapture) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            guard let image = (info[.originalImage] as? UIImage),
                  let data = image.jpegData(compressionQuality: 0.85) else {
                parent.onCancel(); return
            }
            parent.onPicked(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onCancel()
        }
    }
}
