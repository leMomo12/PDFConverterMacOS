//
//  ContentView.swift
//  PDFConverter
//
//  Created by Maurice Nowotni on 31.07.24.
//

import SwiftUI

struct ContentView: View {
    @State var filename = "name"
    @State var fileURL: URL?
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("PDF Converter").padding()
            Text(filename)
            Button("Brows File") {
                print("Here i am")
                let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK {
                            self.fileURL = panel.url
                            self.filename = panel.url?.lastPathComponent ?? "<none>"
                        }
            }.padding()
            Button("Convert to PDF") {
                convertToPDF()
            }.padding()
        }
        .padding()
    }
    
    func convertToPDF() {
            guard let url = fileURL else { return }
            // Determine file type and handle accordingly
            if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "png" {
                createPDF(from: url)
            } else {
                filename = "Path extension not supported"
            }
        }

        func createPDF(from imageURL: URL) {
            guard let image = NSImage(contentsOf: imageURL) else { return }
            
            let pdfData = NSMutableData()
            let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
            var mediaBox = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
            context.beginPDFPage(nil)
            
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            context.draw(cgImage!, in: mediaBox)
            
            context.endPDFPage()
            context.closePDF()
            // Save the PDF to the desktop
            let saveURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(filename).pdf")
            pdfData.write(to: saveURL, atomically: true)
            print("PDF Data size: \(pdfData.length) bytes")

            print("PDF saved to: \(saveURL)")
        }
}

#Preview {
    ContentView()
}
