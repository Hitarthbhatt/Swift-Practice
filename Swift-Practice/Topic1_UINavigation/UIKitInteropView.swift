import SwiftUI
import UIKit

// MARK: - UIKit Interop
// Interview: "How do you integrate UIKit components in a SwiftUI app?"
//
// Two key protocols:
// 1. UIViewRepresentable       — wrap a UIView in SwiftUI
// 2. UIViewControllerRepresentable — wrap a UIViewController in SwiftUI
//
// Reverse direction:
// - UIHostingController — embed SwiftUI views inside UIKit
//
// Senior/Staff considerations:
// - Coordinator pattern (UIKit delegate) bridges UIKit callbacks → SwiftUI
// - Memory: UIKit views are NOT recreated on state change, only updated
// - Threading: UIKit must always be on main thread

// MARK: - UIViewRepresentable Example: wrapping UITextView
struct UIKitTextView: UIViewRepresentable {
    @Binding var text: String

    // 1. Create the UIKit view
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.delegate = context.coordinator
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        return textView
    }

    // 2. Update when SwiftUI state changes
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    // 3. Coordinator bridges UIKit delegate → SwiftUI binding
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}

// MARK: - UIViewControllerRepresentable Example: wrapping a UIKit VC
struct UIKitColorPickerView: UIViewControllerRepresentable {
    @Binding var selectedColor: Color

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedColor: $selectedColor)
    }

    class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var selectedColor: Binding<Color>

        init(selectedColor: Binding<Color>) {
            self.selectedColor = selectedColor
        }

        func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
            selectedColor.wrappedValue = Color(viewController.selectedColor)
        }
    }
}

// MARK: - Demo View
struct UIKitInteropView: View {
    @State private var text = "Type here... this is a UITextView wrapped in SwiftUI"
    @State private var selectedColor: Color = .blue
    @State private var showColorPicker = false

    var body: some View {
        List {
            Section("UIViewRepresentable — UITextView") {
                UIKitTextView(text: $text)
                    .frame(height: 120)

                Text("Character count: \(text.count)")
                    .foregroundStyle(.secondary)
            }

            Section("UIViewControllerRepresentable") {
                HStack {
                    Text("Selected color:")
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 30, height: 30)
                    Spacer()
                    Button("Pick Color") { showColorPicker = true }
                }
            }

            Section("UIHostingController (reverse)") {
                Text("Use UIHostingController(rootView: SomeSwiftUIView()) to embed SwiftUI inside UIKit view controllers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("UIKit Interop")
        .sheet(isPresented: $showColorPicker) {
            UIKitColorPickerView(selectedColor: $selectedColor)
        }
    }
}

#Preview {
    NavigationStack {
        UIKitInteropView()
    }
}
