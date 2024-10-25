import SwiftUI
import CoreML
import Vision

// UIViewControllerRepresentable to handle the image picking process
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage? // Holds the selected image
    @Binding var selectedImageName: String // Holds the identified image name
    @Binding var selectedImagePrecise: String // Holds the confidence percentage
    @Binding var isPresented: Bool // Controls the picker presentation
    var sourceType: UIImagePickerController.SourceType // Determines the source (camera or photo library)
    
    // Create the image picker controller
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType // Set the source type (camera or gallery)
        return picker
    }
    
    // No updates needed for the picker itself
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    // Coordinator to handle delegate methods for the image picker
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Coordinator class conforms to UIImagePickerControllerDelegate and UINavigationControllerDelegate
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        // Called when an image is selected
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage // Set the selected image
                guard let ciImage = CIImage(image: uiImage) else {
                    fatalError("Couldn't convert UIImage to CIImage")
                }
                detect(image: ciImage) // Run CoreML image detection
            }
            parent.isPresented = false // Dismiss the picker
        }
        
        // Called when the image picker is canceled
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false // Dismiss the picker
        }
        
        // Detect objects using CoreML and Vision
        func detect(image: CIImage) {
            guard let model = try? VNCoreMLModel(for: MobileNetV2().model) else {
                fatalError("Couldn't load CoreML model")
            }
            
            // Vision request to perform image classification
            let request = VNCoreMLRequest(model: model) { (request, error) in
                guard let results = request.results as? [VNClassificationObservation] else {
                    fatalError("Model didn't return any results")
                }
                
                // Update the UI with the first result
                if let firstResult = results.first {
                    self.parent.selectedImageName = "This is \(firstResult.identifier.capitalized)"
                    self.parent.selectedImagePrecise = "with \(String(format: "%.2f", firstResult.confidence * 100))% confidence"
                } else {
                    self.parent.selectedImageName = "Can't identify this image"
                }
            }
            
            let handler = VNImageRequestHandler(ciImage: image)
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
}

struct ContentView: View {
    @State private var selectedImage: UIImage? = nil // Holds the selected image
    @State private var selectedImageName: String = "What is this?" // Default message
    @State private var selectedImagePrecise: String = "Select an image to find out 🥰" // Default message
    @State private var isImagePickerPresented = false // Controls the image picker presentation
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary // Default to photo library
    
    var body: some View {
        VStack {
            // Display the result text (image name and confidence)
            VStack(alignment: .leading) {
                Text(selectedImageName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(selectedImagePrecise)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.horizontal, 25)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack {
                // Display the selected image or a placeholder
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 350)
                        .cornerRadius(10)
                        .padding(.bottom, 25)
                }
                
                // Buttons for selecting or taking a photo
                HStack {
                    Button("Select Image") {
                        imagePickerSourceType = .photoLibrary // Set source type to Photo Library
                        isImagePickerPresented = true // Present the picker
                    }
                    .padding()
                    .background(Color.primary)
                    .foregroundColor(.accentColor)
                    .cornerRadius(10)
                    
                    Button("Take an Image") {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            imagePickerSourceType = .camera // Set source type to Camera
                            isImagePickerPresented = true // Present the picker
                        } else {
                            print("Camera not available on this device")
                        }
                    }
                    .padding()
                    .background(Color.primary)
                    .foregroundColor(.accentColor)
                    .cornerRadius(10)
                }
                .padding(.bottom, 25)
            }
            .sheet(isPresented: $isImagePickerPresented) {
                // Present the custom ImagePicker with the correct source type
                ImagePicker(selectedImage: $selectedImage, selectedImageName: $selectedImageName, selectedImagePrecise: $selectedImagePrecise, isPresented: $isImagePickerPresented, sourceType: imagePickerSourceType)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
